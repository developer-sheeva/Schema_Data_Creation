-- =====================================================================
-- Khaustan restaurant onboarding: Shubham Pure Vegetarian Restaurant
-- Source file      : shubham_pure_vegetarian_restaurant_menu.json
-- Target database : KhaustanRestaurantMenu (PostgreSQL 15+)
-- Namespace        : establishment_id = restaurant_id = source_id = 400014001
--                    (supplied inside the JSON: restaurant.establishment_id / restaurant_id)
-- =====================================================================
-- ID CONVENTIONS USED IN THIS FILE (all IDs are explicit literals; no sequences,
-- no nextval(), no CREATE SEQUENCE / DROP SEQUENCE anywhere in this script)
--   Mandatory 12-digit namespace (400014001001 ... ), one independent counter per table:
--     menu_board, menu_category, menu_item, menu_item_variant, menu_item_price,
--     menu_item_availability, menu_board_item
--   Other standalone ids (not in the mandatory list) use 4000140010001 ... per table
--     (13 digits, so they can never collide with the 12-digit namespace):
--     menu_extraction_batch, restaurant_phone, restaurant_hours, restaurant_tag,
--     bundle, addon_group, addon_option
--   canonical_dish: NO rows are inserted by this script. Every menu_item.canonical_dish_id is an id that
--     already exists in the live canonical_dish table (332 distinct dishes: 219 exact-name matches +
--     113 further existing dishes matched as spelling/word-order/prefix variants) or NULL where no equivalent dish
--     exists (96 dishes, flagged - see the CANONICAL DISHES section). A pre-flight check verifies every
--     (id, normalized_name) pair against the database. canonical_dish_name ids are therefore not used.
-- LOOKUP TABLES ARE READ-ONLY HERE: service_mode and platform_tag ids are read with
-- sub-selects on their codes. Nothing is inserted into any lookup table.
-- Market-price items: none in this menu, so the ck_menu_item_price_amount note does
-- not apply to this script.
-- The script runs in ONE transaction. Any error (including the pre-flight checks)
-- leaves the transaction aborted and COMMIT then performs a ROLLBACK.
-- =====================================================================

\connect "KhaustanRestaurantMenu"
BEGIN;

-- ---------------------------------------------------------------------
-- PRE-FLIGHT CHECKS (idempotency + read-only lookups + canonical snapshot)
-- ---------------------------------------------------------------------
DO $preflight$
DECLARE
    c text;
    n integer;
BEGIN
    IF EXISTS (SELECT 1 FROM establishment WHERE establishment_id = 400014001)
       OR EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = 400014001)
       OR EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 400014001 AND source_id = 400014001 AND status_code = 'completed') THEN
        RAISE EXCEPTION 'Restaurant 400014001 is already onboarded (or a completed extraction batch exists) - aborting to avoid duplicate menu items';
    END IF;
    FOREACH c IN ARRAY ARRAY['PURE_VEG','JAIN_AVAILABLE','cuisine_chinese','cuisine_southindian'] LOOP
        IF NOT EXISTS (SELECT 1 FROM platform_tag WHERE tag_code = c) THEN
            RAISE EXCEPTION 'Missing lookup row: platform_tag.tag_code = % (add it in a separate lookup script)', c;
        END IF;
    END LOOP;
    FOREACH c IN ARRAY ARRAY['takeaway','delivery'] LOOP
        IF NOT EXISTS (SELECT 1 FROM service_mode WHERE code = c) THEN
            RAISE EXCEPTION 'Missing lookup row: service_mode.code = % (add it in a separate lookup script)', c;
        END IF;
    END LOOP;
    -- canonical_dish: this script creates NO canonical_dish / canonical_dish_name rows. Every
    -- menu_item.canonical_dish_id used below must already exist in canonical_dish with the expected
    -- normalized_name. (A mismatch means canonical_dish changed after this script was generated.)
    SELECT count(*) INTO n
    FROM (VALUES
        (10019,'aloo chaat'),
        (10044,'baby corn chilly'),
        (10061,'batata vada'),
        (10065,'benne masala dosa'),
        (10068,'bhindi masala fry'),
        (10080,'butter idli'),
        (10084,'butter onion uttappam'),
        (10087,'butter sada dosa'),
        (10088,'butter uttappam'),
        (10100,'cauliflower manchurian'),
        (10110,'chatni sandwich'),
        (10134,'cheese grill sandwich'),
        (10138,'cheese masala dosa'),
        (10140,'cheese masala pav'),
        (10146,'cheese mysore masala dosa'),
        (10148,'cheese mysore sada dosa'),
        (10152,'cheese onion uttapa'),
        (10154,'cheese pakoda'),
        (10161,'cheese pav bhaji'),
        (10164,'cheese pizza'),
        (10166,'cheese sada dosa'),
        (10167,'cheese sandwich'),
        (10171,'cheese toast sandwich'),
        (10172,'cheese tomato uttapa'),
        (10174,'cheese uttappam'),
        (10179,'chilli dosa'),
        (10196,'chinese bhel'),
        (10207,'coconut uttappa'),
        (10225,'dahi idli'),
        (10227,'dahi misal pav'),
        (10229,'dahi wada'),
        (10253,'finger chips'),
        (10311,'hara bhara kabab masala'),
        (10325,'idli chilly'),
        (10327,'idli fry'),
        (10330,'idli vada mix'),
        (10336,'jain cheese pav bhaji'),
        (10349,'jain pav bhaji'),
        (10350,'jain pizza'),
        (10377,'kanda poha (only morning)'),
        (10382,'khada cheese pav bhaji'),
        (10421,'masala dosa'),
        (10426,'masala pav (2 pcs)'),
        (10432,'masala uttappa'),
        (10446,'medu wada'),
        (10456,'misal pav'),
        (10457,'mix pakoda'),
        (10460,'mix vada'),
        (10473,'mushroom cheese pizza'),
        (10478,'mushroom crispy'),
        (10481,'mushroom manchurian'),
        (10484,'mushroom pav bhaji'),
        (10489,'mushroom tawa'),
        (10493,'mysore masala dosa'),
        (10498,'mysore rawa masala dosa'),
        (10499,'mysore rawa sada dosa'),
        (10500,'mysore sada dosa'),
        (10510,'onion bhajiya'),
        (10523,'onion rawa masala dosa'),
        (10524,'onion rawa sada dosa'),
        (10527,'onion tomato uttapa'),
        (10529,'onion uttapa'),
        (10540,'paneer 65'),
        (10563,'paneer chilly'),
        (10567,'paneer chilly dry'),
        (10571,'paneer crispy'),
        (10591,'paneer manchurian'),
        (10592,'paneer manchurian dry'),
        (10599,'paneer mushroom spring roll'),
        (10603,'paneer pakoda'),
        (10604,'paneer pav bhaji'),
        (10629,'paneer tawa masala'),
        (10631,'paneer tikka'),
        (10643,'paneer uttappa'),
        (10645,'panner cheese sada uttapa'),
        (10654,'paper dosa'),
        (10658,'pav bhaji'),
        (10710,'rawa masala dosa'),
        (10711,'rawa sada dosa'),
        (10722,'sabudana wada'),
        (10726,'sada dosa'),
        (10727,'sada pav'),
        (10747,'schezwan sada dosa'),
        (10751,'schzewan cheese sada dosa'),
        (10754,'set dosa'),
        (10766,'soyabean chilly'),
        (10767,'soyabean manchurian'),
        (10770,'special pav bhaji'),
        (10773,'spring dosa'),
        (10777,'steam idli'),
        (10781,'sweet coconut dosa'),
        (10783,'sweet kachori'),
        (10794,'tawa idli'),
        (10813,'tomato uttapa'),
        (10822,'usal pav'),
        (10823,'uttapam plain'),
        (10826,'vada usal (potato)'),
        (10827,'veg burger'),
        (10829,'veg cheese grilled sandwich'),
        (10830,'veg cheese pizza'),
        (10834,'veg club sandwich'),
        (10836,'veg grilled sandwich'),
        (10846,'veg seekh kabab'),
        (10849,'veg. 65'),
        (10857,'veg. cheese sandwich'),
        (10858,'veg. cheese toast sandwich'),
        (10871,'veg. crispy'),
        (10872,'veg. cutlet'),
        (10880,'veg. manchurian'),
        (10881,'veg. manchurian dry'),
        (10886,'veg. sandwich'),
        (10890,'veg. spring roll'),
        (10894,'veg. toast sandwich'),
        (11020,'tomato omlet sandwich'),
        (13013,'aloo chole'),
        (13014,'aloo gobi'),
        (13015,'aloo methi'),
        (13017,'aloo mutter'),
        (13019,'aloo palak'),
        (13020,'aloo simla'),
        (13059,'badam pista'),
        (13060,'baigan masala'),
        (13062,'baingan bharta'),
        (13066,'beetroot'),
        (13067,'begum bahar'),
        (13072,'bharwan aloo'),
        (13093,'boiled vegetables'),
        (13120,'carrot'),
        (13121,'casatta'),
        (13129,'chana masala'),
        (13133,'cheese biryani'),
        (13134,'cheese butter masala'),
        (13143,'cheese kofta'),
        (13154,'cheese tawa pulao'),
        (13162,'chilli garlic noodles'),
        (13175,'chocolate'),
        (13192,'combination rice'),
        (13219,'curd rice'),
        (13224,'dahi bhendi'),
        (13235,'dal fry'),
        (13237,'dal fry butter'),
        (13242,'dal khichdi'),
        (13245,'dal kolhapuri'),
        (13247,'dal makhani'),
        (13252,'dal rice'),
        (13254,'dal tadka'),
        (13275,'dragon rice'),
        (13277,'dum aloo kashmiri'),
        (13278,'dum aloo punjabi'),
        (13279,'dum biryani'),
        (13331,'ginger lemon'),
        (13342,'green peas masala'),
        (13349,'green peas pulav'),
        (13356,'handi biryani'),
        (13365,'hong kong fried rice'),
        (13371,'hot & sour soup'),
        (13383,'hyderabadi biryani'),
        (13387,'jam toast'),
        (13388,'jam toast butter'),
        (13395,'jeera rice'),
        (13402,'kaju curry'),
        (13407,'kaju makhanwala'),
        (13409,'kaju masala'),
        (13412,'kaju pulav'),
        (13419,'kashmiri pulav'),
        (13430,'keser pista'),
        (13448,'koya kaju'),
        (13486,'malai kofta'),
        (13495,'manchow soup'),
        (13502,'manchurian rice with gravy (veg)'),
        (13523,'methi malai mutter'),
        (13544,'mix fried rice'),
        (13557,'mix vegetable'),
        (13570,'mushroom biryani'),
        (13577,'mushroom fried rice'),
        (13581,'mushroom handi'),
        (13586,'mushroom kadai'),
        (13588,'mushroom makhanwala'),
        (13592,'mushroom masala'),
        (13597,'mushroom mutter masala'),
        (13602,'mushroom schezwan fried rice'),
        (13606,'mushroom tawa pulav'),
        (13615,'nargis kofta'),
        (13621,'navratan korma'),
        (13622,'nescafe'),
        (13632,'only bhaji'),
        (13652,'palak dosa'),
        (13659,'palak rice'),
        (13662,'palak soup'),
        (13668,'paper masala'),
        (13688,'plain curd'),
        (13692,'plain palak'),
        (13694,'plain sweet corn soup'),
        (13724,'rose'),
        (13727,'sabudana khichdi'),
        (13744,'schezwan fried rice'),
        (13746,'schezwan noodles'),
        (13763,'singapore fried rice'),
        (13764,'singapore noodles'),
        (13769,'sitaphal'),
        (13793,'steam rice'),
        (13831,'tawa pulao'),
        (13865,'tomato soup'),
        (13870,'triple schezwan fried rice'),
        (13871,'triple schezwan noodles'),
        (13879,'upma'),
        (13885,'veg bhuna'),
        (13897,'veg chinese chop suey'),
        (13899,'veg clear soup'),
        (13913,'veg hungama'),
        (13942,'veg patiala'),
        (13971,'veg. american chopsuey'),
        (13977,'veg. biryani'),
        (14029,'paneer amrutisari'),
        (14035,'paneer bhurji'),
        (14038,'paneer biryani'),
        (14044,'paneer butter masala'),
        (14048,'paneer chatpata'),
        (14069,'paneer fried rice'),
        (14072,'paneer handi'),
        (14097,'paneer kadai'),
        (14104,'paneer kofta'),
        (14106,'paneer kolhapuri'),
        (14108,'paneer koliwada'),
        (14115,'paneer lahori'),
        (14116,'paneer lajawab'),
        (14121,'paneer lazeez'),
        (14129,'paneer makhanwala'),
        (14138,'paneer masala'),
        (14151,'paneer mutter'),
        (14163,'paneer palak'),
        (14165,'paneer paratha'),
        (14166,'paneer pasanda'),
        (14170,'paneer pulao'),
        (14181,'paneer schezwan fried rice'),
        (14198,'paneer tawa pulao'),
        (14202,'paneer tikka biryani'),
        (14204,'paneer tikka masala'),
        (15045,'tomato omelette'),
        (23003,'aloo paratha'),
        (23007,'bhatura'),
        (23008,'bread butter'),
        (23013,'butter chapati'),
        (23016,'butter garlic naan'),
        (23017,'butter kulcha'),
        (23020,'butter naan'),
        (23023,'butter paratha'),
        (23024,'butter roti'),
        (23027,'chapati'),
        (23037,'cheese paratha'),
        (23042,'chole bhature'),
        (23044,'dahi batata puri'),
        (23055,'gobi paratha'),
        (23061,'kulcha'),
        (23072,'masala kulcha'),
        (23080,'naan'),
        (23081,'onion paratha'),
        (23085,'paratha'),
        (23092,'puri bhaji'),
        (23093,'puri shrikhand'),
        (23094,'roti'),
        (23101,'sev puri'),
        (23109,'stuff paratha'),
        (23127,'toast bread butter'),
        (40005,'butter scotch'),
        (40022,'kesar pista kulfi'),
        (40023,'malai kulfi'),
        (40035,'vanilla'),
        (50002,'all cold drinks'),
        (50005,'anjeer milkshake'),
        (50033,'chaas'),
        (50036,'chocolate milk shake'),
        (50040,'cold coffee'),
        (50053,'dry fruit milk shake'),
        (50057,'filter coffee'),
        (50060,'fresh lime juice'),
        (50061,'fresh lime soda'),
        (50081,'kesar falooda'),
        (50082,'kesar lassi'),
        (50084,'kesar pista milk shake'),
        (50089,'kulfi falooda'),
        (50099,'mango falooda'),
        (50102,'mango lassi'),
        (50109,'milk'),
        (50133,'royal falooda'),
        (50136,'salted lassi'),
        (50138,'sikandar sharbat'),
        (50142,'soda'),
        (50145,'special tea'),
        (50152,'sweet lassi'),
        (50154,'tea'),
        (53001,'cocktail'),
        (60006,'apple'),
        (60012,'banana'),
        (60016,'boondi raita'),
        (60026,'chikoo'),
        (60048,'fruit salad'),
        (60053,'fruit salad with jelly'),
        (60054,'fruit salad with jelly & ice cream'),
        (60057,'fry papad'),
        (60058,'grapes'),
        (60061,'green salad'),
        (60062,'gulab jamun'),
        (60073,'jelly with ice-cream'),
        (60085,'mango'),
        (60086,'mango (seasonal)'),
        (60095,'masala papad'),
        (60098,'matka rabdi'),
        (60107,'papad'),
        (60110,'pineapple'),
        (60114,'pineapple raita'),
        (60116,'plain jelly'),
        (60118,'pomegranate (anar)'),
        (60126,'roasted papad'),
        (60134,'sheera'),
        (60143,'strawberry'),
        (60154,'veg thali'),
        (60158,'veg. chowmein noodles'),
        (60168,'veg. fried rice'),
        (60179,'veg. hakka noodles'),
        (60229,'veg. mumtaj'),
        (60236,'veg. noodle soup'),
        (60242,'veg. pulao'),
        (60244,'veg. raita'),
        (60268,'veg. sweet & sour'),
        (60270,'veg. sweet corn soup'),
        (60331,'watermelon'),
        (60345,'special falooda'),
        (60353,'bournvita'),
        (60408,'misal'),
        (60413,'p. samosa'),
        (60462,'veg. fried noodles')
    ) AS v(id, norm)
    JOIN canonical_dish d ON d.canonical_dish_id = v.id AND d.normalized_name = v.norm;
    IF n <> 332 THEN
        RAISE EXCEPTION 'Only % of 332 referenced canonical_dish (id, normalized_name) pairs match the database - canonical_dish has changed since this script was generated; regenerate this script', n;
    END IF;
END
$preflight$;

-- ---------------------------------------------------------------------
-- ESTABLISHMENT / RESTAURANT / SOURCE / EXTRACTION BATCH
-- Source: JSON, "restaurant"
-- state is not in the JSON -> default 'Maharashtra' (data rule 8); bar_license_type
-- is not in the JSON -> default 'none' (data rule 8); email/website are empty in JSON -> NULL
-- ---------------------------------------------------------------------
INSERT INTO establishment (
    establishment_id, name, normalized_name, address_line1, address_line2,
    locality, city, state, country_code, postal_code, latitude, longitude
)
VALUES (
    400014001,
    'Shubham Pure Vegetarian Restaurant',
    lower(trim('Shubham Pure Vegetarian Restaurant')),
    'Opposite Swami Narayan Temple, L.N. Road',
    NULL,
    'Dadar (E)',
    'Mumbai',
    'Maharashtra',
    'IN',
    '400014',
    19.0177649,
    72.8440939
);

INSERT INTO restaurant (
    restaurant_id, establishment_id, display_name, normalized_name,
    veg_nonveg_status, has_bar, bar_license_type, is_24_hours
)
VALUES (
    400014001,
    400014001,
    'Shubham Pure Vegetarian Restaurant',
    lower(trim('Shubham Pure Vegetarian Restaurant')),
    'pure_veg',
    FALSE,
    'none',
    FALSE
);

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400014001, 'ai_menu_extraction', 'shubham_pure_vegetarian_restaurant_menu.json');

INSERT INTO menu_extraction_batch (
    extraction_batch_id, restaurant_id, source_id, extractor_version,
    started_at, completed_at, status_code, overall_confidence
)
VALUES (4000140010001, 400014001, 400014001, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed', NULL);

-- ---------------------------------------------------------------------
-- PHONES  Source: JSON, "restaurant.phone" = "9892499158 / 022-24144015 / 022-24144107"
-- One row per number, source order; first number (printed as "DIAL:" on the menu)
-- is_primary. All three are printed as the restaurant's order lines -> business lines.
-- ---------------------------------------------------------------------
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary, is_personal_number)
VALUES
    (4000140010001, 400014001, '9892499158', TRUE, FALSE),
    (4000140010002, 400014001, '022-24144015', FALSE, FALSE),
    (4000140010003, 400014001, '022-24144107', FALSE, FALSE);

-- ---------------------------------------------------------------------
-- HOURS  Source: JSON, "restaurant.timings" = "06 am - 12 am"
-- No day-wise detail in the JSON, so the same single slot is applied to all 7 days.
-- closes_at 00:00 = midnight, i.e. closes_at < opens_at means 'spans midnight'
-- (same wrap-around convention as price_schedule "Late Night").
-- ---------------------------------------------------------------------
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (4000140010001, 400014001, 1, 1, '06:00', '00:00'),
    (4000140010002, 400014001, 2, 1, '06:00', '00:00'),
    (4000140010003, 400014001, 3, 1, '06:00', '00:00'),
    (4000140010004, 400014001, 4, 1, '06:00', '00:00'),
    (4000140010005, 400014001, 5, 1, '06:00', '00:00'),
    (4000140010006, 400014001, 6, 1, '06:00', '00:00'),
    (4000140010007, 400014001, 7, 1, '06:00', '00:00');

-- ---------------------------------------------------------------------
-- RESTAURANT TAGS (read-only lookup via platform_tag.tag_code)
--   PURE_VEG        <- JSON restaurant.pure_veg = true / name "Pure Vegetarian"
--   JAIN_AVAILABLE  <- category "SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)"; Jain Pav Bhaji / Pizza / Salad
--   cuisine_chinese <- categories "CHINESE SOUP", "CHINESE RICE", "CHINESE GRAVY"
--   cuisine_southindian <- category "SOUTH INDIAN SNACKS"
-- ---------------------------------------------------------------------
INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean)
VALUES
    (4000140010001, 400014001, (SELECT tag_id FROM platform_tag WHERE tag_code = 'PURE_VEG'), TRUE),
    (4000140010002, 400014001, (SELECT tag_id FROM platform_tag WHERE tag_code = 'JAIN_AVAILABLE'), TRUE),
    (4000140010003, 400014001, (SELECT tag_id FROM platform_tag WHERE tag_code = 'cuisine_chinese'), TRUE),
    (4000140010004, 400014001, (SELECT tag_id FROM platform_tag WHERE tag_code = 'cuisine_southindian'), TRUE);

-- ---------------------------------------------------------------------
-- SERVICE MODES (read-only lookup via service_mode.code) and DELIVERY
--   takeaway <- page-0 heading "TAKE AWAY MENU"
--   delivery <- "HOME DELIVERY WILL TAKE 30 TO 45 MINUTES"
--   Dine-in is NOT stated in the JSON, so no dine-in row is created.
-- Delivery: the JSON names no delivery partner, so no restaurant_delivery_provider row
-- is created (it needs delivery_charge_type_code, which the JSON does not give).
-- self_delivery_available = TRUE is INFERRED from the restaurant's own "HOME DELIVERY ..."
-- statement and "DIAL:" order lines (see needs-review block).
-- ---------------------------------------------------------------------
INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id, is_active, notes)
VALUES
    (400014001, (SELECT service_mode_id FROM service_mode WHERE code = 'takeaway'), TRUE, 'Menu is headed TAKE AWAY MENU'),
    (400014001, (SELECT service_mode_id FROM service_mode WHERE code = 'delivery'), TRUE, 'HOME DELIVERY WILL TAKE 30 TO 45 MINUTES');

INSERT INTO restaurant_delivery (
    restaurant_id, delivery_available, self_delivery_available, self_delivery_min_order_amount, currency_code, status_code
)
VALUES (400014001, TRUE, TRUE, NULL, 'INR', 'active');

-- ---------------------------------------------------------------------
-- CANONICAL DISHES - THIS SCRIPT INSERTS NO canonical_dish / canonical_dish_name ROWS.
-- menu_item.canonical_dish_id below references only dishes that ALREADY EXIST in canonical_dish
-- (the pre-flight check verifies each id AND its normalized_name against the database):
--   * 219 dishes: exact normalized-name match (ids unchanged).
--   * 117 dishes: the original version of this script created them as new rows (ids 60466..60678), but the
--     same dish already exists (spelling / transliteration variant, word order, redundant 'Veg.' prefix,
--     serving note, or section-implied noun). menu_item.canonical_dish_id points at the existing id; each such
--     line has a trailing comment 'canonical_dish_id: was <old> ... -> existing <id>'.
--   * 96 dishes (96 menu items): NO equivalent exists in canonical_dish. They are NOT created here
--     (rule: use only existing canonical dishes). menu_item.canonical_dish_id is NULL on those lines, each
--     marked 'FLAG: new canonical_dish required'. When the data owner adds the dishes (or maps them to an
--     existing dish), set menu_item.canonical_dish_id for the menu_item_ids listed below.
--   Source of truth for every decision: canonical_dish_reconciliation_400014001_v2.csv
-- 
-- MAPPED, BUT PLEASE CONFIRM (low confidence):
--   Alu Chana -> 13013 'Aloo Chole'  (regional synonym (chana = chole))
--   Half Litre Cold Drink (500ml) -> 50002 'ALL COLD DRINKS'  (pack size of generic cold drink)
--   Can -> 50002 'ALL COLD DRINKS'  (pack type of generic cold drink)
--   Punjabi Samosa -> 60413 'P. Samosa'  (abbreviation (P. = Punjabi))
--   Butter Masala Dosa -> 10065 'BENNE MASALA DOSA'  (regional synonym (benne = butter))
--   Cheese Paneer Uttappa -> 10645 'Panner Cheese Sada Uttapa'  (typo (panner); "sada" = plain base; word order)
--   Khada Handi Cheese Pav Bhaji -> 10382 'Khada Cheese Pav Bhaji'  (word order; extra "handi" is a cooking-vessel note)
--   Mix Veg. Fried Noodles -> 60462 'Veg. Fried Noodles'  ("Mix Veg." = mixed vegetables)
-- 
-- MAPPED, WHERE THE DATABASE HOLDS SEVERAL EQUIVALENT ROWS (closest spelling used as primary):
--   Veg. Patiala -> 13942 'veg patiala'   (also: 60240 'veg. patiyala')
--   Tawa Paneer Masala -> 10629 'paneer tawa masala'   (also: 10628 'paneer tawa'; 10797 'tawa paneer')
--   Boiled Vegetable -> 13093 'boiled vegetables'   (also: 13091 'boiled veg')
--   Dal Fry (in Butter) -> 13237 'dal fry butter'   (also: 13239 'dal fry with butter'; 13115 'butter dal fry')
--   Mushroom Green Peas Masala -> 13597 'mushroom mutter masala'   (also: 13513 'matar mushroom masala'; 13580 'mushroom green peas curry')
--   Paneer Pulav -> 14170 'paneer pulao'   (also: 14222 'veg. paneer pulav')
--   Veg. Pulav -> 60242 'veg. pulao'   (also: 60319 'vegetable pulao')
--   Annar (Pomegranate) -> 60118 'pomegranate (anar)'   (also: 13031 'anar'; 50003 'anar juice')
--   Chikkoo -> 60026 'chikoo'   (also: 60374 'chiku')
--   Sitaphal (Seasonal) -> 13769 'sitaphal'   (also: 60137 'sitafal')
--   Strawberry (Seasonal) -> 60143 'strawberry'   (also: 60117 'plain strawberry')
--   Vanila -> 40035 'vanilla'   (also: 50162 'vanilla milk shake'; 40038 'vanilla ice cream')
--   Dry Fruits Shake -> 50053 'dry fruit milk shake'   (also: 50113 'mix dry fruit milkshake')
--   Milkshake Chocolate -> 50036 'chocolate milk shake'   (also: 50037 'chocolate milk shal')
--   Kesar Pista (Scoop) -> 13430 'keser pista'   (also: 40021 'kesar pista ice cream')
--   Kesar Pista -> 40022 'kesar pista kulfi'   (also: 13430 'keser pista')
--   Idli Wada Mix -> 10330 'idli vada mix'   (also: 13384 'idli & dal vada mix')
--   Veg Cutlet -> 10872 'veg. cutlet'   (also: 60380 'cutlet')
--   Rawa Sada -> 10711 'rawa sada dosa'   (also: 10708 'rava sada dosa')
--   Rawa Masala -> 10710 'rawa masala dosa'   (also: 10705 'rava masala dosa')
--   Onion Rawa Sada -> 10524 'onion rawa sada dosa'   (also: 10521 'onion rava sada dosa'; 10707 'rava onion sada dosa')
--   Onion Rawa Masala -> 10523 'onion rawa masala dosa'   (also: 10520 'onion rava masala dosa'; 10706 'rava onion masala dosa')
--   Rawa Mysore Masala -> 10498 'mysore rawa masala dosa'   (also: 10497 'mysore rava masala dosa')
--   Uttappa Plain -> 10823 'uttapam plain'   (also: 10682 'plain uttapam')
--   Onion Uttappa -> 10529 'onion uttapa'   (also: 10530 'onion uttappam')
--   Cheese Onion Uttappa -> 10152 'cheese onion uttapa'   (also: 10153 'cheese onion uttappam')
--   Tomato Uttappa -> 10813 'tomato uttapa'   (also: 10814 'tomato uttappam')
--   Cheese Tomato Uttappa -> 10172 'cheese tomato uttapa'   (also: 10173 'cheese tomato uttappam')
--   Onion Tomato Uttappa -> 10527 'onion tomato uttapa'   (also: 10528 'onion tomato uttapam'; 10809 'tomato onion uttapa'; 10810 'tomato onion uttappam')
--   Khada Handi Cheese Pav Bhaji -> 10382 'khada cheese pav bhaji'   (also: 10136 'cheese khada pav bhaji')
--   Mushroom Tawa Pulao -> 13606 'mushroom tawa pulav'   (also: 13830 'tawa mushroom pulao')
--   Veg. Cheese Pizza -> 10830 'veg cheese pizza'   (also: 10899 'vegetable cheese pizza')
--   Veg. Burger -> 10827 'veg burger'   (also: 10897 'vegetable burger')
--   Veg. Club Sandwich -> 10834 'veg club sandwich'   (also: 10206 'club sandwich')
--   Veg. Grilled Sandwich -> 10836 'veg grilled sandwich'   (also: 10877 'veg. grill sandwich'; 10307 'grilled sandwich')
--   Veg. Cheese Grilled Sandwich -> 10829 'veg cheese grilled sandwich'   (also: 10898 'vegetable cheese grill sandwich')
--   Cheese Grilled Sandwich -> 10134 'cheese grill sandwich'   (also: 10532 'only cheese grilled sandwich')
--   Veg. Cheese S/W -> 10857 'veg. cheese sandwich'   (also: 10900 'vegetable cheese sandwich'; 10167 'cheese sandwich')
--   Veg. Clear Soup -> 13899 'veg clear soup'   (also: 13190 'clear soup (veg)'; 60295 'vegetable clear soup'; 13189 'clear soup')
--   Veg Manchurian F'd Rice with Gravy -> 13502 'manchurian rice with gravy (veg)'   (also: 60219 'veg. manchurian fried rice')
--   Mix Veg. Fried Noodles -> 60462 'veg. fried noodles'   (also: 13546 'mix noodles')
--   Chilly Garlic Hakka Noodles -> 13162 'chilli garlic noodles'   (also: 13996 'veg. chilli garlic noodles')
--   Veg. Chinese Chopsuey -> 13897 'veg chinese chop suey'   (also: 13169 'chinese chopsuey')
--   Sweet & Sour Veg -> 60268 'veg. sweet & sour'   (also: 13960 'veg sweet n sour')
--   Onion Pakoda -> 10510 'onion bhajiya'   (also: 10376 'kanda bhajiya'; 13415 'kanda bhaji')
--   Veg. Seekh Kebab -> 10846 'veg seekh kabab'   (also: 10907 'vegetable seekh kebab'; 10753 'seekh kebab')
-- 
-- FLAG - NEW canonical_dish RECORDS REQUIRED (96):  name | menu_item_id | closest existing dish (if any) | why it is not the same
--   Tawa Baby Corn Masala | 400014001008 | closest: 13051 'baby corn masala' | "Tawa" (cooking style) is part of the dish; existing row has none
--   Veg. Queen Masala | 400014001015 | closest: none | No Queen/Malika-style veg dish exists
--   Paneer Methi Mutter | 400014001020 | closest: 14140 'paneer methi' | Three-ingredient dish (paneer + methi + mutter); existing rows have two
--   Paneer Tikka Lawadar | 400014001029 | closest: 14114 'paneer lababdar' | "Tikka" version; "Lawadar" is probably "Lababdar" (typo)
--   Shubham Spl. Handi | 400014001033 | closest: none | Restaurant-signature handi; no generic equivalent
--   Soya Bean Masala | 400014001034 | closest: none | No soya-bean masala exists (only soyabean chilly / manchurian / biryani / schezwan)
--   Gobi Banarasi | 400014001056 | closest: none | No Banarasi gobi dish exists
--   Mushroom Paneer Handi | 400014001063 | closest: 13581 'mushroom handi' | Two-ingredient combo (mushroom + paneer)
--   Mushroom Paneer Kadai | 400014001064 | closest: 13586 'mushroom kadai' | Two-ingredient combo (mushroom + paneer)
--   Mushroom Babycorn Handi | 400014001065 | closest: 13581 'mushroom handi' | Two-ingredient combo (mushroom + baby corn)
--   Mushroom Babycorn Kadai | 400014001066 | closest: 13586 'mushroom kadai' | Two-ingredient combo (mushroom + baby corn)
--   Mushroom Kofta | 400014001067 | closest: 13919 'veg kofta' | No mushroom kofta exists
--   Methi Masala | 400014001070 | closest: 13527 'methi mutter masala' | No plain methi masala exists
--   Paneer Badami | 400014001074 | closest: none | No Badami paneer exists
--   Paneer Toofani | 400014001075 | closest: none | No Toofani paneer exists
--   Shahi Pulav | 400014001083 | closest: none | No Shahi pulav exists
--   Navaratan Biryani | 400014001087 | closest: 13937 'veg navratan' | No Navratan biryani exists
--   Makhaniwala Biryani | 400014001089 | closest: none | No Makhanwala biryani exists
--   Kadai Biryani | 400014001095 | closest: none | No Kadai biryani exists
--   Paneer Handi Biryani | 400014001097 | closest: 14223 'vegetable & paneer handi biryani' | Existing row has extra vegetable; near-miss, please confirm
--   Tomato | 400014001136 | closest: none | No tomato juice / flavour exists
--   Badam Pista Kesar Shake | 400014001149 | closest: 50084 'kesar pista milk shake' | Different flavour combination
--   Dry Fruits Kesar Shake | 400014001150 | closest: 50053 'dry fruit milk shake' | Kesar variant not in DB
--   Badam Pista Shake | 400014001153 | closest: 50010 'badam milkshake' | Badam + pista combination not in DB
--   Shahi Lassi | 400014001159 | closest: 50144 'sp. lassi' | "Shahi" lassi is not "special" lassi
--   Jaljeera | 400014001184 | closest: none | No jaljeera drink exists
--   Kesar Kishmish | 400014001191 | closest: 13425 'kesar' | Ice-cream flavour not in DB
--   Usal | 400014001208 | closest: 10822 'usal pav' | DB keeps base dish and "with pav" separate (misal / misal pav); no plain usal
--   Dahi Misal | 400014001212 | closest: 10227 'dahi misal pav' | DB keeps base dish and "with pav" separate; near-miss, please confirm
--   Butter Mysore Sada | 400014001228 | closest: 10500 'mysore sada dosa' | Butter version; DB keeps butter/ghee/cheese versions as separate dishes
--   Butter Mysore Masala | 400014001231 | closest: 10493 'mysore masala dosa' | Butter version; DB keeps butter/ghee/cheese versions separate
--   Butter Rawa Sada | 400014001234 | closest: 10711 'rawa sada dosa' | Butter version; DB keeps butter/ghee/cheese versions separate
--   Cheese Rawa Sada | 400014001235 | closest: 10711 'rawa sada dosa' | Cheese version not in DB
--   Butter Rawa Masala | 400014001237 | closest: 10710 'rawa masala dosa' | Butter version; DB keeps butter/ghee/cheese versions separate
--   Cheese Rawa Masala | 400014001238 | closest: 10710 'rawa masala dosa' | Cheese version not in DB
--   Butter Onion Rawa Sada | 400014001240 | closest: 10524 'onion rawa sada dosa' | Butter version not in DB (only ghee)
--   Cheese Onion Rawa Sada | 400014001241 | closest: 10524 'onion rawa sada dosa' | Cheese version not in DB
--   Butter Onion Rawa Masala | 400014001243 | closest: 10523 'onion rawa masala dosa' | Butter version not in DB (only ghee)
--   Cheese Onion Rawa Masala | 400014001244 | closest: 10523 'onion rawa masala dosa' | Cheese version not in DB
--   Shubham Special Dosa | 400014001249 | closest: 10768 'special masala dosa' | Restaurant-signature dosa; no generic "special dosa"
--   Triple Decker Dosa | 400014001250 | closest: none | No triple-decker dosa exists
--   Paneer Cheese Dosa | 400014001251 | closest: 10158 'cheese panner masala dosa' | Paneer + cheese combination without masala not in DB
--   Anand Dosa | 400014001252 | closest: none | Restaurant-specific dosa
--   Cheese Palak Dosa | 400014001254 | closest: 13652 'palak dosa' | Cheese version not in DB
--   Manchurian Dosa | 400014001257 | closest: none | No manchurian dosa exists
--   Chopsuey Dosa | 400014001258 | closest: 10029 'american chopsuey dosa' | Only American / Schezwan chopsuey dosas exist
--   Spl. Uttappa | 400014001263 | closest: none | No special uttappa exists
--   Butter Tomato Uttappa | 400014001271 | closest: 10813 'tomato uttapa' | Butter version not in DB
--   Butter Tomato Onion Uttappa | 400014001274 | closest: 10527 'onion tomato uttapa' | Butter version not in DB
--   Cheese Tomato Onion Uttappa | 400014001275 | closest: 10172 'cheese tomato uttapa' | Cheese + tomato + onion combination not in DB
--   Cheese Coconut Uttappa | 400014001277 | closest: 10207 'coconut uttappa' | Cheese version not in DB
--   Butter Palak Uttappa | 400014001281 | closest: none | No palak uttappa exists
--   Cheese Palak Uttappa | 400014001282 | closest: none | No palak uttappa exists
--   Butter Pineapple Uttappa | 400014001284 | closest: none | No pineapple uttappa exists
--   Upwas Pattice | 400014001289 | closest: none | No fasting (upwas) pattice exists
--   Rajgiri Puri Bhaji | 400014001290 | closest: 23092 'puri bhaji' | Rajgiri (fasting) puri is a different dish
--   Kheer | 400014001291 | closest: none | No kheer exists
--   Custard | 400014001294 | closest: 60018 'caramel custard' | Plain custard is not caramel custard
--   Seasonal Only Aam Ras | 400014001297 | closest: none | No aam ras exists
--   Aam Ras Puri (Seasonal) | 400014001298 | closest: none | No aam ras puri exists
--   Palak Pizza | 400014001323 | closest: none | No palak pizza exists
--   Tandoor Paneer Pizza | 400014001325 | closest: none | No tandoor / tandoori paneer pizza exists
--   Corn Mushroom Pizza | 400014001326 | closest: none | No corn + mushroom pizza exists
--   Mushroom Onion Tomato Pizza | 400014001327 | closest: none | No mushroom + onion + tomato pizza exists
--   Schezwan Paneer Pizza | 400014001328 | closest: none | No schezwan paneer pizza exists
--   Veg. Supreme Pizza | 400014001329 | closest: none | No supreme pizza exists
--   Washington Pizza | 400014001330 | closest: none | No Washington pizza exists
--   Green Cheese Burger | 400014001331 | closest: 10114 'cheese burger' | "Green" cheese burger is a different burger
--   Paneer Cheese Grilled Sandwich | 400014001336 | closest: 10551 'paneer cheese melting sandwich' | No paneer-cheese grilled sandwich exists
--   Veg. Jumbo Sandwich | 400014001337 | closest: none | No jumbo sandwich exists
--   Veg. Cheese Jumbo | 400014001338 | closest: none | No jumbo sandwich exists
--   Toast Tomato Omlet Sandwich | 400014001346 | closest: 11020 'tomato omlet sandwich' | DB keeps toast sandwiches separate (e.g. cheese sandwich vs cheese toast sandwich)
--   Bhel Puri | 400014001353 | closest: none | No plain bhel / bhel puri exists (only chinese / mexican / puneri / kolhapuri bhel)
--   Special Bhel Puri | 400014001355 | closest: none | No plain bhel / bhel puri exists
--   Sev Batata Puri | 400014001356 | closest: 23101 'sev puri' | Sev Puri and Sev Batata Puri are separate items on this menu
--   Noodle Spring Roll | 400014001370 | closest: 10776 'spring roll' | Noodle-filled spring roll is a different dish
--   Babycorn Manchurian Dry | 400014001375 | closest: 10045 'baby corn manchurian' | DB keeps dry and gravy manchurian separate (veg. manchurian vs veg. manchurian dry)
--   Gobi Manchurian Dry | 400014001376 | closest: 10296 'gobi manchurian' | DB keeps dry and gravy manchurian separate
--   Mushroom Manchurian Dry | 400014001377 | closest: 10481 'mushroom manchurian' | DB keeps dry and gravy manchurian separate
--   Shubham Spl. Fried Rice with Gravy | 400014001381 | closest: none | Restaurant-signature dish
--   Baby Corn Schezwan Fried Rice | 400014001392 | closest: 13744 'schezwan fried rice' | Baby-corn version not in DB
--   Cauliflower Schezwan Fried Rice | 400014001395 | closest: 13744 'schezwan fried rice' | Cauliflower version not in DB
--   Veg. Manchow Noodles | 400014001399 | closest: 13933 'veg manchow' | 13933 is a soup, not noodles
--   Veg. Dragon Noodles | 400014001405 | closest: none | No dragon noodles exists
--   Paneer Schezwan Noodles | 400014001408 | closest: 14156 'paneer noodles' | Schezwan paneer noodles not in DB
--   Mushroom Schezwan Noodles | 400014001409 | closest: 13746 'schezwan noodles' | Mushroom schezwan noodles not in DB
--   Paneer Chilly in Green Sauce | 400014001417 | closest: 60417 'paneer chilly bean sauce' | Green-sauce version not in DB
--   Paneer Chilly in Red Sauce | 400014001418 | closest: 60417 'paneer chilly bean sauce' | Red-sauce version not in DB
--   Veg. Ball Chilly | 400014001419 | closest: none | No veg ball chilly exists
--   Veg. Ball Mushroom in Red Sauce | 400014001420 | closest: none | No veg ball + mushroom dish exists
--   Diced Veg. with (M) in Green Sauce | 400014001421 | closest: none | No diced-veg green-sauce dish exists
--   Fried Veg. in Garlic Sauce | 400014001422 | closest: none | No fried veg in garlic sauce exists
--   Jain Salad | 400014001430 | closest: none | No jain salad exists
--   Masala Raita | 400014001433 | closest: 60121 'raita' | Masala raita is not plain raita
--   Paneer Hara Kebab | 400014001443 | closest: 10310 'hara bhara kabab' | Paneer hara kebab is a different kebab
--   Gobi Tikka | 400014001445 | closest: none | No gobi tikka exists
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- MENU BOARD (single a_la_carte board: the JSON is one overall menu with no board labels)
-- ---------------------------------------------------------------------
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, display_sequence)
VALUES (400014001001, 400014001, 'Menu', 'a_la_carte', 1);

-- ---------------------------------------------------------------------
-- MENU CATEGORIES (32) - leaf-level, flat, JSON source order, verbatim text.
-- The empty heading pages[1].sections[17] "HOT / COLD BEVERAGES" has no items and is NOT created
-- (see unmapped notes).
-- ---------------------------------------------------------------------
INSERT INTO menu_category (menu_category_id, restaurant_id, parent_category_id, name, display_sequence)
VALUES
    (400014001001, 400014001, NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 1),  -- pages[0].sections[0]
    (400014001002, 400014001, NULL, 'SABZI MANDI SE', 2),  -- pages[0].sections[1]
    (400014001003, 400014001, NULL, 'BASMATI CHAWAL KA KAMAL', 3),  -- pages[0].sections[2]
    (400014001004, 400014001, NULL, 'ATTA KA KAMAL', 4),  -- pages[0].sections[3]
    (400014001005, 400014001, NULL, 'JUICE', 5),  -- pages[0].sections[4]
    (400014001006, 400014001, NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 6),  -- pages[0].sections[5]
    (400014001007, 400014001, NULL, 'LASSI', 7),  -- pages[0].sections[6]
    (400014001008, 400014001, NULL, 'FALOODA', 8),  -- pages[0].sections[7]
    (400014001009, 400014001, NULL, 'JELLY & FRUIT SALAD', 9),  -- pages[0].sections[8]
    (400014001010, 400014001, NULL, 'HOT BEVERAGES', 10),  -- pages[0].sections[9]
    (400014001011, 400014001, NULL, 'COLD BEVERAGES', 11),  -- pages[0].sections[10]
    (400014001012, 400014001, NULL, 'ICECREAM / DESSERTS', 12),  -- pages[0].sections[11]
    (400014001013, 400014001, NULL, 'KULFI', 13),  -- pages[0].sections[12]
    (400014001014, 400014001, NULL, 'SOUTH INDIAN SNACKS', 14),  -- pages[1].sections[0]
    (400014001015, 400014001, NULL, 'DOSA''S', 15),  -- pages[1].sections[1]
    (400014001016, 400014001, NULL, 'UTTAPPAS', 16),  -- pages[1].sections[2]
    (400014001017, 400014001, NULL, 'FASTING ITEM', 17),  -- pages[1].sections[3]
    (400014001018, 400014001, NULL, 'SWEET', 18),  -- pages[1].sections[4]
    (400014001019, 400014001, NULL, 'PURI WITH', 19),  -- pages[1].sections[5]
    (400014001020, 400014001, NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 20),  -- pages[1].sections[6]
    (400014001021, 400014001, NULL, 'PIZZA & BURGERS', 21),  -- pages[1].sections[7]
    (400014001022, 400014001, NULL, 'SANDWICHES', 22),  -- pages[1].sections[8]
    (400014001023, 400014001, NULL, 'CHAT', 23),  -- pages[1].sections[9]
    (400014001024, 400014001, NULL, 'CHINESE SOUP', 24),  -- pages[1].sections[10]
    (400014001025, 400014001, NULL, 'TO START WITH', 25),  -- pages[1].sections[11]
    (400014001026, 400014001, NULL, 'CHINESE RICE', 26),  -- pages[1].sections[12]
    (400014001027, 400014001, NULL, 'NOODLES', 27),  -- pages[1].sections[13]
    (400014001028, 400014001, NULL, 'CHINESE GRAVY', 28),  -- pages[1].sections[14]
    (400014001029, 400014001, NULL, 'KHANE KE SAATH SAATH', 29),  -- pages[1].sections[15]
    (400014001030, 400014001, NULL, 'INDIAN STARTERS', 30),  -- pages[1].sections[16]
    (400014001031, 400014001, NULL, 'NEW LUCKY FAMILY PACK', 31),  -- pages[1].sections[18]
    (400014001032, 400014001, NULL, 'SALADS & RAITA', 32);  -- pages[1].sections[19]

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400014001, 400014001001, 400014001001, 1),
    (400014001, 400014001001, 400014001002, 2),
    (400014001, 400014001001, 400014001003, 3),
    (400014001, 400014001001, 400014001004, 4),
    (400014001, 400014001001, 400014001005, 5),
    (400014001, 400014001001, 400014001006, 6),
    (400014001, 400014001001, 400014001007, 7),
    (400014001, 400014001001, 400014001008, 8),
    (400014001, 400014001001, 400014001009, 9),
    (400014001, 400014001001, 400014001010, 10),
    (400014001, 400014001001, 400014001011, 11),
    (400014001, 400014001001, 400014001012, 12),
    (400014001, 400014001001, 400014001013, 13),
    (400014001, 400014001001, 400014001014, 14),
    (400014001, 400014001001, 400014001015, 15),
    (400014001, 400014001001, 400014001016, 16),
    (400014001, 400014001001, 400014001017, 17),
    (400014001, 400014001001, 400014001018, 18),
    (400014001, 400014001001, 400014001019, 19),
    (400014001, 400014001001, 400014001020, 20),
    (400014001, 400014001001, 400014001021, 21),
    (400014001, 400014001001, 400014001022, 22),
    (400014001, 400014001001, 400014001023, 23),
    (400014001, 400014001001, 400014001024, 24),
    (400014001, 400014001001, 400014001025, 25),
    (400014001, 400014001001, 400014001026, 26),
    (400014001, 400014001001, 400014001027, 27),
    (400014001, 400014001001, 400014001028, 28),
    (400014001, 400014001001, 400014001029, 29),
    (400014001, 400014001001, 400014001030, 30),
    (400014001, 400014001001, 400014001031, 31),
    (400014001, 400014001001, 400014001032, 32);

-- =====================================================================
-- MENU ITEMS, VARIANTS AND PRICES (450 items / 457 variants / 456 prices)
-- Slash alternatives on one printed line become separate menu_item rows sharing split_group_key
-- (e.g. "Kaju Khoya / Kaju Curry"). Prices carry GST regime/exclusive per the page text
-- "GST APPLICABLE AS PER GOVT. RATES" (rate not stated -> NULL). service_mode_id is NULL
-- (price applies to the menu as printed). effective_from = load time (UTC).
-- =====================================================================

-- ---- CATEGORY 400014001001: SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)

-- Source: JSON, "pages[0].sections[0].columns[0].items[0]" -- Veg. Hangama | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001001, 400014001, 400014001001, 13913, 'Veg. Hangama', 'veg. hangama', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60466 (new row in original script) -> existing 13913 'Veg Hungama'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001001, 400014001001, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001001, 400014001001, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[1]" -- Veg. Patiala | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001002, 400014001, 400014001001, 13942, 'Veg. Patiala', 'veg. patiala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60467 (new row in original script) -> existing 13942 'VEG PATIALA'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001002, 400014001002, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001002, 400014001002, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[2]" -- Veg. Boona | 320
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001003, 400014001, 400014001001, 13885, 'Veg. Boona', 'veg. boona', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60468 (new row in original script) -> existing 13885 'Veg Bhuna'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001003, 400014001003, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001003, 400014001003, 320.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[3]" -- Veg. Begum Bahar | 300
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001004, 400014001, 400014001001, 13067, 'Veg. Begum Bahar', 'veg. begum bahar', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60469 (new row in original script) -> existing 13067 'Begum Bahar'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001004, 400014001004, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001004, 400014001004, 300.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[4]" -- Veg. Hara Bhara Kabab Masala | 320
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001005, 400014001, 400014001001, 10311, 'Veg. Hara Bhara Kabab Masala', 'veg. hara bhara kabab masala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60470 (new row in original script) -> existing 10311 'Hara Bhara Kabab Masala'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001005, 400014001005, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001005, 400014001005, 320.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[5]" -- Tawa Mushroom / Paneer Masala | 310
-- REVIEW: name expanded from shortened source line "Tawa Mushroom / Paneer Masala"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001006, 400014001, 400014001001, 10489, 'Tawa Mushroom Masala', 'tawa mushroom masala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, '400014001-P0S0I5', 'needs_review');  -- canonical_dish_id: was 60471 (new row in original script) -> existing 10489 'Mushroom Tawa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001006, 400014001006, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001006, 400014001006, 310.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[5]" -- Tawa Mushroom / Paneer Masala | 310
-- REVIEW: name expanded from shortened source line "Tawa Mushroom / Paneer Masala"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001007, 400014001, 400014001001, 10629, 'Tawa Paneer Masala', 'tawa paneer masala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, '400014001-P0S0I5', 'needs_review');  -- canonical_dish_id: was 60472 (new row in original script) -> existing 10629 'PANEER TAWA MASALA'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001007, 400014001007, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001007, 400014001007, 310.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[6]" -- Tawa Baby Corn Masala | 320
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001008, 400014001, 400014001001, NULL, 'Tawa Baby Corn Masala', 'tawa baby corn masala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Tawa Baby Corn Masala' [was 60473]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001008, 400014001008, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001008, 400014001008, 320.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[7]" -- Cheese Butter Masala | 320
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001009, 400014001, 400014001001, 13134, 'Cheese Butter Masala', 'cheese butter masala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001009, 400014001009, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001009, 400014001009, 320.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[8]" -- Kaju Khoya / Kaju Curry | 299
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001010, 400014001, 400014001001, 13448, 'Kaju Khoya', 'kaju khoya', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, '400014001-P0S0I8', 'unverified');  -- canonical_dish_id: was 60474 (new row in original script) -> existing 13448 'Koya Kaju'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001010, 400014001010, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001010, 400014001010, 299.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[8]" -- Kaju Khoya / Kaju Curry | 299
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001011, 400014001, 400014001001, 13402, 'Kaju Curry', 'kaju curry', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, '400014001-P0S0I8', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001011, 400014001011, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001011, 400014001011, 299.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[9]" -- Kaju Masala / Kaju Makhanwala | 299
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001012, 400014001, 400014001001, 13409, 'Kaju Masala', 'kaju masala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, '400014001-P0S0I9', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001012, 400014001012, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001012, 400014001012, 299.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[9]" -- Kaju Masala / Kaju Makhanwala | 299
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001013, 400014001, 400014001001, 13407, 'Kaju Makhanwala', 'kaju makhanwala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, '400014001-P0S0I9', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001013, 400014001013, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001013, 400014001013, 299.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[10]" -- Veg. Mumtaz | 310
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001014, 400014001, 400014001001, 60229, 'Veg. Mumtaz', 'veg. mumtaz', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60475 (new row in original script) -> existing 60229 'Veg. Mumtaj'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001014, 400014001014, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001014, 400014001014, 310.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[11]" -- Veg. Queen Masala | 320
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001015, 400014001, 400014001001, NULL, 'Veg. Queen Masala', 'veg. queen masala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Veg. Queen Masala' [was 60476]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001015, 400014001015, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001015, 400014001015, 320.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[12]" -- Paneer Chatpata | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001016, 400014001, 400014001001, 14048, 'Paneer Chatpata', 'paneer chatpata', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001016, 400014001016, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001016, 400014001016, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[13]" -- Paneer Palak / Paneer Mutter | 265
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001017, 400014001, 400014001001, 14163, 'Paneer Palak', 'paneer palak', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, '400014001-P0S0I13', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001017, 400014001017, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001017, 400014001017, 265.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[13]" -- Paneer Palak / Paneer Mutter | 265
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001018, 400014001, 400014001001, 14151, 'Paneer Mutter', 'paneer mutter', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, '400014001-P0S0I13', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001018, 400014001018, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001018, 400014001018, 265.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[14]" -- Paneer Masala | 285
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001019, 400014001, 400014001001, 14138, 'Paneer Masala', 'paneer masala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001019, 400014001019, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001019, 400014001019, 285.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[15]" -- Paneer Methi Mutter | 285
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001020, 400014001, 400014001001, NULL, 'Paneer Methi Mutter', 'paneer methi mutter', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Paneer Methi Mutter' [was 60477]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001020, 400014001020, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001020, 400014001020, 285.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[16]" -- Paneer Bhurji | 299
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001021, 400014001, 400014001001, 14035, 'Paneer Bhurji', 'paneer bhurji', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001021, 400014001021, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001021, 400014001021, 299.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[17]" -- Paneer Makhanwala | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001022, 400014001, 400014001001, 14129, 'Paneer Makhanwala', 'paneer makhanwala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001022, 400014001022, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001022, 400014001022, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[18]" -- Paneer Butter Masala | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001023, 400014001, 400014001001, 14044, 'Paneer Butter Masala', 'paneer butter masala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001023, 400014001023, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001023, 400014001023, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[19]" -- Paneer Pasanda | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001024, 400014001, 400014001001, 14166, 'Paneer Pasanda', 'paneer pasanda', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001024, 400014001024, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001024, 400014001024, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[20]" -- Paneer Amritsari | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001025, 400014001, 400014001001, 14029, 'Paneer Amritsari', 'paneer amritsari', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60478 (new row in original script) -> existing 14029 'Paneer Amrutisari'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001025, 400014001025, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001025, 400014001025, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[21]" -- Paneer Tikka Masala | 310
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001026, 400014001, 400014001001, 14204, 'Paneer Tikka Masala', 'paneer tikka masala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001026, 400014001026, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001026, 400014001026, 310.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[22]" -- Paneer Handi / Paneer Kadai | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001027, 400014001, 400014001001, 14072, 'Paneer Handi', 'paneer handi', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, '400014001-P0S0I22', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001027, 400014001027, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001027, 400014001027, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[22]" -- Paneer Handi / Paneer Kadai | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001028, 400014001, 400014001001, 14097, 'Paneer Kadai', 'paneer kadai', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, '400014001-P0S0I22', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001028, 400014001028, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001028, 400014001028, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[23]" -- Paneer Tikka Lawadar | 320
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001029, 400014001, 400014001001, NULL, 'Paneer Tikka Lawadar', 'paneer tikka lawadar', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Paneer Tikka Lawadar' [was 60479]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001029, 400014001029, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001029, 400014001029, 320.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[24]" -- Paneer Lazeez / Paneer Kofta | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001030, 400014001, 400014001001, 14121, 'Paneer Lazeez', 'paneer lazeez', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, '400014001-P0S0I24', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001030, 400014001030, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001030, 400014001030, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[24]" -- Paneer Lazeez / Paneer Kofta | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001031, 400014001, 400014001001, 14104, 'Paneer Kofta', 'paneer kofta', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, '400014001-P0S0I24', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001031, 400014001031, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001031, 400014001031, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[25]" -- Plain Palak | 195
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001032, 400014001, 400014001001, 13692, 'Plain Palak', 'plain palak', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001032, 400014001032, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001032, 400014001032, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[26]" -- Shubham Spl. Handi | 320
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001033, 400014001, 400014001001, NULL, 'Shubham Spl. Handi', 'shubham spl. handi', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Shubham Spl. Handi' [was 60480]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001033, 400014001033, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001033, 400014001033, 320.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[0].columns[0].items[27]" -- Soya Bean Masala | 270
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001034, 400014001, 400014001001, NULL, 'Soya Bean Masala', 'soya bean masala', NULL, 'SHUBHAM VEG. SPECIAL (ALSO AVAILABLE IN JAIN)', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Soya Bean Masala' [was 60481]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001034, 400014001034, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001034, 400014001034, 270.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001002: SABZI MANDI SE

-- Source: JSON, "pages[0].sections[1].columns[0].items[0]" -- Alu Mutter / Alu Chana | 195
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001035, 400014001, 400014001002, 13017, 'Alu Mutter', 'alu mutter', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I0', 'unverified');  -- canonical_dish_id: was 60482 (new row in original script) -> existing 13017 'ALOO MUTTER'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001035, 400014001035, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001035, 400014001035, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[0]" -- Alu Mutter / Alu Chana | 195
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001036, 400014001, 400014001002, 13013, 'Alu Chana', 'alu chana', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I0', 'unverified');  -- canonical_dish_id: was 60483 (new row in original script) -> existing 13013 'Aloo Chole'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001036, 400014001036, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001036, 400014001036, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[1]" -- Alu Palak | 195
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001037, 400014001, 400014001002, 13019, 'Alu Palak', 'alu palak', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60484 (new row in original script) -> existing 13019 'ALOO PALAK'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001037, 400014001037, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001037, 400014001037, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[2]" -- Alu Gobi | 200
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001038, 400014001, 400014001002, 13014, 'Alu Gobi', 'alu gobi', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60485 (new row in original script) -> existing 13014 'ALOO GOBI'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001038, 400014001038, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001038, 400014001038, 200.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[3]" -- Alu Methi / Alu Simia | 195
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001039, 400014001, 400014001002, 13015, 'Alu Methi', 'alu methi', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I3', 'unverified');  -- canonical_dish_id: was 60486 (new row in original script) -> existing 13015 'Aloo Methi'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001039, 400014001039, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001039, 400014001039, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[3]" -- Alu Methi / Alu Simia | 195
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001040, 400014001, 400014001002, 13020, 'Alu Simia', 'alu simia', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I3', 'unverified');  -- canonical_dish_id: was 60487 (new row in original script) -> existing 13020 'Aloo Simla'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001040, 400014001040, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001040, 400014001040, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[4]" -- Baigan Masala / Baigan Bhartha | 210
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001041, 400014001, 400014001002, 13060, 'Baigan Masala', 'baigan masala', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I4', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001041, 400014001041, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001041, 400014001041, 210.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[4]" -- Baigan Masala / Baigan Bhartha | 210
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001042, 400014001, 400014001002, 13062, 'Baigan Bhartha', 'baigan bhartha', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I4', 'unverified');  -- canonical_dish_id: was 60488 (new row in original script) -> existing 13062 'Baingan Bharta'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001042, 400014001042, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001042, 400014001042, 210.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[5]" -- Bhendi Masala Fry | 220
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001043, 400014001, 400014001002, 10068, 'Bhendi Masala Fry', 'bhendi masala fry', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60489 (new row in original script) -> existing 10068 'Bhindi Masala Fry'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001043, 400014001043, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001043, 400014001043, 220.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[6]" -- Boiled Vegetable | 199
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001044, 400014001, 400014001002, 13093, 'Boiled Vegetable', 'boiled vegetable', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60490 (new row in original script) -> existing 13093 'Boiled Vegetables'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001044, 400014001044, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001044, 400014001044, 199.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[7]" -- Chole Bhature | 240
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001045, 400014001, 400014001002, 23042, 'Chole Bhature', 'chole bhature', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001045, 400014001045, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001045, 400014001045, 240.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[8]" -- Cheese Kofta | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001046, 400014001, 400014001002, 13143, 'Cheese Kofta', 'cheese kofta', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001046, 400014001046, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001046, 400014001046, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[9]" -- Chana Masala | 205
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001047, 400014001, 400014001002, 13129, 'Chana Masala', 'chana masala', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001047, 400014001047, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001047, 400014001047, 205.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[10]" -- Dal Fry / Dal Fry (in Butter) | 160 / 185
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001048, 400014001, 400014001002, 13235, 'Dal Fry', 'dal fry', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I10', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001048, 400014001048, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001048, 400014001048, 160.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[10]" -- Dal Fry / Dal Fry (in Butter) | 160 / 185
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001049, 400014001, 400014001002, 13237, 'Dal Fry (in Butter)', 'dal fry (in butter)', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I10', 'unverified');  -- canonical_dish_id: was 60491 (new row in original script) -> existing 13237 'Dal Fry Butter'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001049, 400014001049, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001049, 400014001049, 185.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[11]" -- Dal Tadka / Dal Makhani | 195 / 225
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001050, 400014001, 400014001002, 13254, 'Dal Tadka', 'dal tadka', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I11', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001050, 400014001050, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001050, 400014001050, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[11]" -- Dal Tadka / Dal Makhani | 195 / 225
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001051, 400014001, 400014001002, 13247, 'Dal Makhani', 'dal makhani', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I11', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001051, 400014001051, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001051, 400014001051, 225.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[12]" -- Dal Kolhapuri | 195
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001052, 400014001, 400014001002, 13245, 'Dal Kolhapuri', 'dal kolhapuri', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001052, 400014001052, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001052, 400014001052, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[13]" -- Dum Alu Kashmiri | 270
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001053, 400014001, 400014001002, 13277, 'Dum Alu Kashmiri', 'dum alu kashmiri', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60492 (new row in original script) -> existing 13277 'Dum Aloo Kashmiri'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001053, 400014001053, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001053, 400014001053, 270.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[14]" -- Dum Alu Punjabi | 250
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001054, 400014001, 400014001002, 13278, 'Dum Alu Punjabi', 'dum alu punjabi', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60493 (new row in original script) -> existing 13278 'DUM ALOO PUNJABI'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001054, 400014001054, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001054, 400014001054, 250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[15]" -- Dahi Bhendi | 270
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001055, 400014001, 400014001002, 13224, 'Dahi Bhendi', 'dahi bhendi', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001055, 400014001055, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001055, 400014001055, 270.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[16]" -- Gobi Banarasi | 270
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001056, 400014001, 400014001002, NULL, 'Gobi Banarasi', 'gobi banarasi', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Gobi Banarasi' [was 60494]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001056, 400014001056, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001056, 400014001056, 270.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[17]" -- Green Peas Masala | 220
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001057, 400014001, 400014001002, 13342, 'Green Peas Masala', 'green peas masala', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001057, 400014001057, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001057, 400014001057, 220.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[18]" -- Mushroom Masala | 270
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001058, 400014001, 400014001002, 13592, 'Mushroom Masala', 'mushroom masala', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001058, 400014001058, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001058, 400014001058, 270.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[19]" -- Mushroom Makhanwala | 270
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001059, 400014001, 400014001002, 13588, 'Mushroom Makhanwala', 'mushroom makhanwala', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001059, 400014001059, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001059, 400014001059, 270.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[20]" -- Mushroom Green Peas Masala | 270
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001060, 400014001, 400014001002, 13597, 'Mushroom Green Peas Masala', 'mushroom green peas masala', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60495 (new row in original script) -> existing 13597 'Mushroom Mutter Masala'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001060, 400014001060, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001060, 400014001060, 270.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[21]" -- Mushroom Handi / Kadai | 275
-- REVIEW: name expanded from shortened source line "Mushroom Handi / Kadai"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001061, 400014001, 400014001002, 13581, 'Mushroom Handi', 'mushroom handi', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I21', 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001061, 400014001061, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001061, 400014001061, 275.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[21]" -- Mushroom Handi / Kadai | 275
-- REVIEW: name expanded from shortened source line "Mushroom Handi / Kadai"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001062, 400014001, 400014001002, 13586, 'Mushroom Kadai', 'mushroom kadai', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I21', 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001062, 400014001062, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001062, 400014001062, 275.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[22]" -- Mushroom Paneer Handi / Kadai | 290
-- REVIEW: name expanded from shortened source line "Mushroom Paneer Handi / Kadai"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001063, 400014001, 400014001002, NULL, 'Mushroom Paneer Handi', 'mushroom paneer handi', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I22', 'needs_review');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Mushroom Paneer Handi' [was 60496]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001063, 400014001063, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001063, 400014001063, 290.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[22]" -- Mushroom Paneer Handi / Kadai | 290
-- REVIEW: name expanded from shortened source line "Mushroom Paneer Handi / Kadai"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001064, 400014001, 400014001002, NULL, 'Mushroom Paneer Kadai', 'mushroom paneer kadai', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I22', 'needs_review');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Mushroom Paneer Kadai' [was 60497]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001064, 400014001064, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001064, 400014001064, 290.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[23]" -- Mushroom Babycorn Handi / Kadai | 290
-- REVIEW: name expanded from shortened source line "Mushroom Babycorn Handi / Kadai"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001065, 400014001, 400014001002, NULL, 'Mushroom Babycorn Handi', 'mushroom babycorn handi', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I23', 'needs_review');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Mushroom Babycorn Handi' [was 60498]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001065, 400014001065, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001065, 400014001065, 290.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[23]" -- Mushroom Babycorn Handi / Kadai | 290
-- REVIEW: name expanded from shortened source line "Mushroom Babycorn Handi / Kadai"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001066, 400014001, 400014001002, NULL, 'Mushroom Babycorn Kadai', 'mushroom babycorn kadai', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I23', 'needs_review');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Mushroom Babycorn Kadai' [was 60499]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001066, 400014001066, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001066, 400014001066, 290.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[24]" -- Mushroom Kofta | 310
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001067, 400014001, 400014001002, NULL, 'Mushroom Kofta', 'mushroom kofta', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Mushroom Kofta' [was 60500]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001067, 400014001067, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001067, 400014001067, 310.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[25]" -- Mix Vegetable | 270
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001068, 400014001, 400014001002, 13557, 'Mix Vegetable', 'mix vegetable', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001068, 400014001068, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001068, 400014001068, 270.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[26]" -- Malai Kofta | 275
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001069, 400014001, 400014001002, 13486, 'Malai Kofta', 'malai kofta', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001069, 400014001069, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001069, 400014001069, 275.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[27]" -- Methi Masala | 255
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001070, 400014001, 400014001002, NULL, 'Methi Masala', 'methi masala', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Methi Masala' [was 60501]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001070, 400014001070, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001070, 400014001070, 255.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[28]" -- Methi Malai Mutter | 275
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001071, 400014001, 400014001002, 13523, 'Methi Malai Mutter', 'methi malai mutter', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001071, 400014001071, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001071, 400014001071, 275.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[29]" -- Navratna Kurma | 275
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001072, 400014001, 400014001002, 13621, 'Navratna Kurma', 'navratna kurma', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60502 (new row in original script) -> existing 13621 'Navratan Korma'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001072, 400014001072, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001072, 400014001072, 275.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[30]" -- Nargis Kofta | 280
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001073, 400014001, 400014001002, 13615, 'Nargis Kofta', 'nargis kofta', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001073, 400014001073, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001073, 400014001073, 280.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[31]" -- Paneer Badami / Paneer Toofani | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001074, 400014001, 400014001002, NULL, 'Paneer Badami', 'paneer badami', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I31', 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Paneer Badami' [was 60503]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001074, 400014001074, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001074, 400014001074, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[31]" -- Paneer Badami / Paneer Toofani | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001075, 400014001, 400014001002, NULL, 'Paneer Toofani', 'paneer toofani', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I31', 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Paneer Toofani' [was 60504]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001075, 400014001075, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001075, 400014001075, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[32]" -- Paneer Lahori / Paneer Koliwada | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001076, 400014001, 400014001002, 14115, 'Paneer Lahori', 'paneer lahori', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I32', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001076, 400014001076, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001076, 400014001076, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[32]" -- Paneer Lahori / Paneer Koliwada | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001077, 400014001, 400014001002, 14108, 'Paneer Koliwada', 'paneer koliwada', NULL, 'SABZI MANDI SE', 'veg', NULL, '400014001-P0S1I32', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001077, 400014001077, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001077, 400014001077, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[33]" -- Paneer Kolhapuri | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001078, 400014001, 400014001002, 14106, 'Paneer Kolhapuri', 'paneer kolhapuri', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001078, 400014001078, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001078, 400014001078, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[1].columns[0].items[34]" -- Paneer Lajawab | 310
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001079, 400014001, 400014001002, 14116, 'Paneer Lajawab', 'paneer lajawab', NULL, 'SABZI MANDI SE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001079, 400014001079, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001079, 400014001079, 310.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001003: BASMATI CHAWAL KA KAMAL

-- Source: JSON, "pages[0].sections[2].columns[0].items[0]" -- Kaju Pulav | 240
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001080, 400014001, 400014001003, 13412, 'Kaju Pulav', 'kaju pulav', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001080, 400014001080, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001080, 400014001080, 240.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[1]" -- Paneer Pulav | 240
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001081, 400014001, 400014001003, 14170, 'Paneer Pulav', 'paneer pulav', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60505 (new row in original script) -> existing 14170 'PANEER PULAO'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001081, 400014001081, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001081, 400014001081, 240.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[2]" -- Kashmiri Pulav / Shahi Pulav | 240
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001082, 400014001, 400014001003, 13419, 'Kashmiri Pulav', 'kashmiri pulav', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, '400014001-P0S2I2', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001082, 400014001082, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001082, 400014001082, 240.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[2]" -- Kashmiri Pulav / Shahi Pulav | 240
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001083, 400014001, 400014001003, NULL, 'Shahi Pulav', 'shahi pulav', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, '400014001-P0S2I2', 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Shahi Pulav' [was 60506]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001083, 400014001083, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001083, 400014001083, 240.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[3]" -- Green Peas Pulav | 235
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001084, 400014001, 400014001003, 13349, 'Green Peas Pulav', 'green peas pulav', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001084, 400014001084, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001084, 400014001084, 235.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[4]" -- Veg. Pulav | 215
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001085, 400014001, 400014001003, 60242, 'Veg. Pulav', 'veg. pulav', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60507 (new row in original script) -> existing 60242 'VEG. PULAO'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001085, 400014001085, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001085, 400014001085, 215.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[5]" -- Paneer Biryani / Navaratan Biryani | 240
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001086, 400014001, 400014001003, 14038, 'Paneer Biryani', 'paneer biryani', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, '400014001-P0S2I5', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001086, 400014001086, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001086, 400014001086, 240.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[5]" -- Paneer Biryani / Navaratan Biryani | 240
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001087, 400014001, 400014001003, NULL, 'Navaratan Biryani', 'navaratan biryani', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, '400014001-P0S2I5', 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Navaratan Biryani' [was 60508]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001087, 400014001087, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001087, 400014001087, 240.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[6]" -- Paneer Tikka Biryani | 285
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001088, 400014001, 400014001003, 14202, 'Paneer Tikka Biryani', 'paneer tikka biryani', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001088, 400014001088, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001088, 400014001088, 285.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[7]" -- Makhaniwala Biryani | 260
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001089, 400014001, 400014001003, NULL, 'Makhaniwala Biryani', 'makhaniwala biryani', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Makhaniwala Biryani' [was 60509]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001089, 400014001089, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001089, 400014001089, 260.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[8]" -- Hyderabadi Biryani | 260
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001090, 400014001, 400014001003, 13383, 'Hyderabadi Biryani', 'hyderabadi biryani', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001090, 400014001090, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001090, 400014001090, 260.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[9]" -- Cheese Biryani | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001091, 400014001, 400014001003, 13133, 'Cheese Biryani', 'cheese biryani', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001091, 400014001091, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001091, 400014001091, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[10]" -- Mushroom Biryani | 265
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001092, 400014001, 400014001003, 13570, 'Mushroom Biryani', 'mushroom biryani', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001092, 400014001092, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001092, 400014001092, 265.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[11]" -- Dum Biryani | 285
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001093, 400014001, 400014001003, 13279, 'Dum Biryani', 'dum biryani', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001093, 400014001093, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001093, 400014001093, 285.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[12]" -- Handi Biryani / Kadai Biryani | 245
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001094, 400014001, 400014001003, 13356, 'Handi Biryani', 'handi biryani', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, '400014001-P0S2I12', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001094, 400014001094, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001094, 400014001094, 245.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[12]" -- Handi Biryani / Kadai Biryani | 245
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001095, 400014001, 400014001003, NULL, 'Kadai Biryani', 'kadai biryani', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, '400014001-P0S2I12', 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Kadai Biryani' [was 60510]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001095, 400014001095, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001095, 400014001095, 245.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[13]" -- Veg. Biryani | 215
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001096, 400014001, 400014001003, 13977, 'Veg. Biryani', 'veg. biryani', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001096, 400014001096, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001096, 400014001096, 215.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[14]" -- Paneer Handi Biryani | 285
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001097, 400014001, 400014001003, NULL, 'Paneer Handi Biryani', 'paneer handi biryani', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Paneer Handi Biryani' [was 60511]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001097, 400014001097, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001097, 400014001097, 285.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[15]" -- Dal Khichda | 215
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001098, 400014001, 400014001003, 13242, 'Dal Khichda', 'dal khichda', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60512 (new row in original script) -> existing 13242 'DAL KHICHDI'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001098, 400014001098, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001098, 400014001098, 215.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[16]" -- Veg Thali | 260
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001099, 400014001, 400014001003, 60154, 'Veg Thali', 'veg thali', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001099, 400014001099, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001099, 400014001099, 260.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[17]" -- Palak Rice | 215
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001100, 400014001, 400014001003, 13659, 'Palak Rice', 'palak rice', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001100, 400014001100, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001100, 400014001100, 215.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[18]" -- Curd Rice | 195
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001101, 400014001, 400014001003, 13219, 'Curd Rice', 'curd rice', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001101, 400014001101, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001101, 400014001101, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[19]" -- Dal Rice | 110
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001102, 400014001, 400014001003, 13252, 'Dal Rice', 'dal rice', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001102, 400014001102, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001102, 400014001102, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[20]" -- Jeera Rice | 199
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001103, 400014001, 400014001003, 13395, 'Jeera Rice', 'jeera rice', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001103, 400014001103, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001103, 400014001103, 199.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[2].columns[0].items[21]" -- Steam Rice | 110
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001104, 400014001, 400014001003, 13793, 'Steam Rice', 'steam rice', NULL, 'BASMATI CHAWAL KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001104, 400014001104, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001104, 400014001104, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001004: ATTA KA KAMAL

-- Source: JSON, "pages[0].sections[3].columns[0].items[0]" -- Roti | 12
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001105, 400014001, 400014001004, 23094, 'Roti', 'roti', NULL, 'ATTA KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001105, 400014001105, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001105, 400014001105, 12.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[1]" -- Chapati | 17
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001106, 400014001, 400014001004, 23027, 'Chapati', 'chapati', NULL, 'ATTA KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001106, 400014001106, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001106, 400014001106, 17.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[2]" -- Butter Chapati / Roti | 27 / 45
-- REVIEW: name expanded from shortened source line "Butter Chapati / Roti"; 27/45 matched positionally to Butter Chapati/Butter Roti; Butter Roti dearer than Butter Chapati is unusual (plain Roti 12, Chapati 17)
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001107, 400014001, 400014001004, 23013, 'Butter Chapati', 'butter chapati', NULL, 'ATTA KA KAMAL', 'veg', NULL, '400014001-P0S3I2', 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001107, 400014001107, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001107, 400014001107, 27.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review');

-- Source: JSON, "pages[0].sections[3].columns[0].items[2]" -- Butter Chapati / Roti | 27 / 45
-- REVIEW: name expanded from shortened source line "Butter Chapati / Roti"; 27/45 matched positionally to Butter Chapati/Butter Roti; Butter Roti dearer than Butter Chapati is unusual (plain Roti 12, Chapati 17)
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001108, 400014001, 400014001004, 23024, 'Butter Roti', 'butter roti', NULL, 'ATTA KA KAMAL', 'veg', NULL, '400014001-P0S3I2', 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001108, 400014001108, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001108, 400014001108, 45.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review');

-- Source: JSON, "pages[0].sections[3].columns[0].items[3]" -- Paratha / Butter Paratha | 60 / 75
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001109, 400014001, 400014001004, 23085, 'Paratha', 'paratha', NULL, 'ATTA KA KAMAL', 'veg', NULL, '400014001-P0S3I3', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001109, 400014001109, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001109, 400014001109, 60.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[3]" -- Paratha / Butter Paratha | 60 / 75
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001110, 400014001, 400014001004, 23023, 'Butter Paratha', 'butter paratha', NULL, 'ATTA KA KAMAL', 'veg', NULL, '400014001-P0S3I3', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001110, 400014001110, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001110, 400014001110, 75.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[4]" -- Alu Paratha / Gobi Paratha | 115
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001111, 400014001, 400014001004, 23003, 'Alu Paratha', 'alu paratha', NULL, 'ATTA KA KAMAL', 'veg', NULL, '400014001-P0S3I4', 'unverified');  -- canonical_dish_id: was 60513 (new row in original script) -> existing 23003 'Aloo Paratha'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001111, 400014001111, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001111, 400014001111, 115.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[4]" -- Alu Paratha / Gobi Paratha | 115
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001112, 400014001, 400014001004, 23055, 'Gobi Paratha', 'gobi paratha', NULL, 'ATTA KA KAMAL', 'veg', NULL, '400014001-P0S3I4', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001112, 400014001112, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001112, 400014001112, 115.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[5]" -- Stuff Paratha | 120
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001113, 400014001, 400014001004, 23109, 'Stuff Paratha', 'stuff paratha', NULL, 'ATTA KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001113, 400014001113, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001113, 400014001113, 120.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[6]" -- Paneer Paratha | 160
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001114, 400014001, 400014001004, 14165, 'Paneer Paratha', 'paneer paratha', NULL, 'ATTA KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001114, 400014001114, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001114, 400014001114, 160.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[7]" -- Cheese Paratha | 180
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001115, 400014001, 400014001004, 23037, 'Cheese Paratha', 'cheese paratha', NULL, 'ATTA KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001115, 400014001115, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001115, 400014001115, 180.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[8]" -- Onion Stuff Paratha | 135
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001116, 400014001, 400014001004, 23081, 'Onion Stuff Paratha', 'onion stuff paratha', NULL, 'ATTA KA KAMAL', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60514 (new row in original script) -> existing 23081 'Onion Paratha'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001116, 400014001116, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001116, 400014001116, 135.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[9]" -- Kulcha / Butter Kulcha | 65 / 80
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001117, 400014001, 400014001004, 23061, 'Kulcha', 'kulcha', NULL, 'ATTA KA KAMAL', 'veg', NULL, '400014001-P0S3I9', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001117, 400014001117, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001117, 400014001117, 65.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[9]" -- Kulcha / Butter Kulcha | 65 / 80
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001118, 400014001, 400014001004, 23017, 'Butter Kulcha', 'butter kulcha', NULL, 'ATTA KA KAMAL', 'veg', NULL, '400014001-P0S3I9', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001118, 400014001118, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001118, 400014001118, 80.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[10]" -- Masala Kulcha | 99
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001119, 400014001, 400014001004, 23072, 'Masala Kulcha', 'masala kulcha', NULL, 'ATTA KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001119, 400014001119, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001119, 400014001119, 99.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[11]" -- Naan | 90
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001120, 400014001, 400014001004, 23080, 'Naan', 'naan', NULL, 'ATTA KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001120, 400014001120, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001120, 400014001120, 90.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[12]" -- Butter Naan | 120
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001121, 400014001, 400014001004, 23020, 'Butter Naan', 'butter naan', NULL, 'ATTA KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001121, 400014001121, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001121, 400014001121, 120.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[13]" -- Butter Garlic Naan | 150
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001122, 400014001, 400014001004, 23016, 'Butter Garlic Naan', 'butter garlic naan', NULL, 'ATTA KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001122, 400014001122, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001122, 400014001122, 150.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[3].columns[0].items[14]" -- Bhatura | 75
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001123, 400014001, 400014001004, 23007, 'Bhatura', 'bhatura', NULL, 'ATTA KA KAMAL', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001123, 400014001123, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001123, 400014001123, 75.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001005: JUICE

-- Source: JSON, "pages[0].sections[4].columns[0].items[0]" -- Apple / Plain | 165 / 175
-- REVIEW: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally; positional label->price match is inferred
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001124, 400014001, 400014001005, NULL, 'Apple / Plain', 'apple / plain', NULL, 'JUICE', 'veg', NULL, NULL, 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001124, 400014001124, 'Apple', 'fixed', NULL, NULL, 1, TRUE),
    (400014001125, 400014001124, 'Plain', 'fixed', NULL, NULL, 2, FALSE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001124, 400014001124, 165.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review'),
    (400014001125, 400014001125, 175.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review');

-- Source: JSON, "pages[0].sections[4].columns[0].items[1]" -- Mosambi / Plain | 110 / 125
-- REVIEW: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally; positional label->price match is inferred
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001125, 400014001, 400014001005, NULL, 'Mosambi / Plain', 'mosambi / plain', NULL, 'JUICE', 'veg', NULL, NULL, 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001126, 400014001125, 'Mosambi', 'fixed', NULL, NULL, 1, TRUE),
    (400014001127, 400014001125, 'Plain', 'fixed', NULL, NULL, 2, FALSE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001126, 400014001126, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review'),
    (400014001127, 400014001127, 125.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review');

-- Source: JSON, "pages[0].sections[4].columns[0].items[2]" -- Orange / Plain | 110 / 125
-- REVIEW: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally; positional label->price match is inferred
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001126, 400014001, 400014001005, NULL, 'Orange / Plain', 'orange / plain', NULL, 'JUICE', 'veg', NULL, NULL, 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001128, 400014001126, 'Orange', 'fixed', NULL, NULL, 1, TRUE),
    (400014001129, 400014001126, 'Plain', 'fixed', NULL, NULL, 2, FALSE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001128, 400014001128, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review'),
    (400014001129, 400014001129, 125.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review');

-- Source: JSON, "pages[0].sections[4].columns[0].items[3]" -- Ganga Jamuna / Plain | 145 / 155  +note: (Mosambi / Orange)
-- REVIEW: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally; positional label->price match is inferred
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001127, 400014001, 400014001005, NULL, 'Ganga Jamuna / Plain', 'ganga jamuna / plain', '(Mosambi / Orange)', 'JUICE', 'veg', NULL, NULL, 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001130, 400014001127, 'Ganga Jamuna', 'fixed', NULL, NULL, 1, TRUE),
    (400014001131, 400014001127, 'Plain', 'fixed', NULL, NULL, 2, FALSE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001130, 400014001130, 145.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review'),
    (400014001131, 400014001131, 155.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review');

-- Source: JSON, "pages[0].sections[4].columns[0].items[5]" -- Mango (Seasonal) | 185
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001128, 400014001, 400014001005, 60086, 'Mango (Seasonal)', 'mango (seasonal)', NULL, 'JUICE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001132, 400014001128, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001132, 400014001132, 185.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[4].columns[0].items[6]" -- Grapes | 150
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001129, 400014001, 400014001005, 60058, 'Grapes', 'grapes', NULL, 'JUICE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001133, 400014001129, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001133, 400014001133, 150.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[4].columns[0].items[7]" -- Cocktail | 155
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001130, 400014001, 400014001005, 53001, 'Cocktail', 'cocktail', NULL, 'JUICE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001134, 400014001130, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001134, 400014001134, 155.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[4].columns[0].items[8]" -- Pineapple Juice / Plain | 150 / 160
-- REVIEW: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally; positional label->price match is inferred
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001131, 400014001, 400014001005, NULL, 'Pineapple Juice / Plain', 'pineapple juice / plain', NULL, 'JUICE', 'veg', NULL, NULL, 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001135, 400014001131, 'Pineapple Juice', 'fixed', NULL, NULL, 1, TRUE),
    (400014001136, 400014001131, 'Plain', 'fixed', NULL, NULL, 2, FALSE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001135, 400014001135, 150.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review'),
    (400014001136, 400014001136, 160.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review');

-- Source: JSON, "pages[0].sections[4].columns[0].items[9]" -- Watermelon / Plain | 110 / 110
-- REVIEW: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally; positional label->price match is inferred
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001132, 400014001, 400014001005, NULL, 'Watermelon / Plain', 'watermelon / plain', NULL, 'JUICE', 'veg', NULL, NULL, 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001137, 400014001132, 'Watermelon', 'fixed', NULL, NULL, 1, TRUE),
    (400014001138, 400014001132, 'Plain', 'fixed', NULL, NULL, 2, FALSE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001137, 400014001137, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review'),
    (400014001138, 400014001138, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review');

-- Source: JSON, "pages[0].sections[4].columns[0].items[10]" -- Mara Mari / Plain | 155 / 165  +note: (Pineapple + Mosambi)
-- REVIEW: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally; positional label->price match is inferred
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001133, 400014001, 400014001005, NULL, 'Mara Mari / Plain', 'mara mari / plain', '(Pineapple + Mosambi)', 'JUICE', 'veg', NULL, NULL, 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001139, 400014001133, 'Mara Mari', 'fixed', NULL, NULL, 1, TRUE),
    (400014001140, 400014001133, 'Plain', 'fixed', NULL, NULL, 2, FALSE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001139, 400014001139, 155.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review'),
    (400014001140, 400014001140, 165.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review');

-- Source: JSON, "pages[0].sections[4].columns[0].items[12]" -- Carrot / Beetroot / Tomato | 100
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001134, 400014001, 400014001005, 13120, 'Carrot', 'carrot', NULL, 'JUICE', 'veg', NULL, '400014001-P0S4I12', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001141, 400014001134, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001141, 400014001141, 100.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[4].columns[0].items[12]" -- Carrot / Beetroot / Tomato | 100
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001135, 400014001, 400014001005, 13066, 'Beetroot', 'beetroot', NULL, 'JUICE', 'veg', NULL, '400014001-P0S4I12', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001142, 400014001135, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001142, 400014001142, 100.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[4].columns[0].items[12]" -- Carrot / Beetroot / Tomato | 100
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001136, 400014001, 400014001005, NULL, 'Tomato', 'tomato', NULL, 'JUICE', 'veg', NULL, '400014001-P0S4I12', 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Tomato' [was 60515]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001143, 400014001136, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001143, 400014001143, 100.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[4].columns[0].items[13]" -- Annar (Pomegranate) | 150
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001137, 400014001, 400014001005, 60118, 'Annar (Pomegranate)', 'annar (pomegranate)', NULL, 'JUICE', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60516 (new row in original script) -> existing 60118 'Pomegranate (anar)'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001144, 400014001137, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001144, 400014001144, 150.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001006: MILK SHAKES (WITH ICE CREAM 30/- EXTRA)

-- Source: JSON, "pages[0].sections[5].columns[0].items[0]" -- Chikkoo / Apple / Pineapple | 160
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001138, 400014001, 400014001006, 60026, 'Chikkoo', 'chikkoo', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, '400014001-P0S5I0', 'unverified');  -- canonical_dish_id: was 60517 (new row in original script) -> existing 60026 'Chikoo'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001145, 400014001138, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001145, 400014001145, 160.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[0]" -- Chikkoo / Apple / Pineapple | 160
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001139, 400014001, 400014001006, 60006, 'Apple', 'apple', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, '400014001-P0S5I0', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001146, 400014001139, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001146, 400014001146, 160.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[0]" -- Chikkoo / Apple / Pineapple | 160
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001140, 400014001, 400014001006, 60110, 'Pineapple', 'pineapple', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, '400014001-P0S5I0', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001147, 400014001140, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001147, 400014001147, 160.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[1]" -- Mango / Sitaphal (Seasonal) | 199
-- REVIEW: name expanded from shortened source line "Mango / Sitaphal (Seasonal)"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001141, 400014001, 400014001006, 60086, 'Mango (Seasonal)', 'mango (seasonal)', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, '400014001-P0S5I1', 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001148, 400014001141, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001148, 400014001148, 199.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[1]" -- Mango / Sitaphal (Seasonal) | 199
-- REVIEW: name expanded from shortened source line "Mango / Sitaphal (Seasonal)"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001142, 400014001, 400014001006, 13769, 'Sitaphal (Seasonal)', 'sitaphal (seasonal)', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, '400014001-P0S5I1', 'needs_review');  -- canonical_dish_id: was 60518 (new row in original script) -> existing 13769 'Sitaphal'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001149, 400014001142, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001149, 400014001149, 199.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[2]" -- Strawberry (Seasonal) | 210
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001143, 400014001, 400014001006, 60143, 'Strawberry (Seasonal)', 'strawberry (seasonal)', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60519 (new row in original script) -> existing 60143 'Strawberry'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001150, 400014001143, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001150, 400014001150, 210.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[3]" -- Banana | 145
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001144, 400014001, 400014001006, 60012, 'Banana', 'banana', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001151, 400014001144, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001151, 400014001151, 145.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[4]" -- Watermelon | 145
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001145, 400014001, 400014001006, 60331, 'Watermelon', 'watermelon', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001152, 400014001145, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001152, 400014001152, 145.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[5]" -- Rose / Vanila | 135
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001146, 400014001, 400014001006, 13724, 'Rose', 'rose', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, '400014001-P0S5I5', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001153, 400014001146, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001153, 400014001153, 135.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[5]" -- Rose / Vanila | 135
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001147, 400014001, 400014001006, 40035, 'Vanila', 'vanila', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, '400014001-P0S5I5', 'unverified');  -- canonical_dish_id: was 60520 (new row in original script) -> existing 40035 'Vanilla'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001154, 400014001147, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001154, 400014001154, 135.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[6]" -- Kesar Pista Shake | 260
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001148, 400014001, 400014001006, 50084, 'Kesar Pista Shake', 'kesar pista shake', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60521 (new row in original script) -> existing 50084 'Kesar Pista Milk Shake'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001155, 400014001148, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001155, 400014001155, 260.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[7]" -- Badam Pista Kesar Shake | 260
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001149, 400014001, 400014001006, NULL, 'Badam Pista Kesar Shake', 'badam pista kesar shake', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Badam Pista Kesar Shake' [was 60522]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001156, 400014001149, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001156, 400014001156, 260.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[8]" -- Dry Fruits Kesar Shake | 260
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001150, 400014001, 400014001006, NULL, 'Dry Fruits Kesar Shake', 'dry fruits kesar shake', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Dry Fruits Kesar Shake' [was 60523]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001157, 400014001150, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001157, 400014001157, 260.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[9]" -- Dry Fruits Shake | 260
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001151, 400014001, 400014001006, 50053, 'Dry Fruits Shake', 'dry fruits shake', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60524 (new row in original script) -> existing 50053 'Dry Fruit Milk Shake'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001158, 400014001151, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001158, 400014001158, 260.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[10]" -- Anjeer Shake | 220
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001152, 400014001, 400014001006, 50005, 'Anjeer Shake', 'anjeer shake', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60525 (new row in original script) -> existing 50005 'Anjeer Milkshake'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001159, 400014001152, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001159, 400014001159, 220.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[11]" -- Badam Pista Shake | 275
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001153, 400014001, 400014001006, NULL, 'Badam Pista Shake', 'badam pista shake', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Badam Pista Shake' [was 60526]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001160, 400014001153, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001160, 400014001160, 275.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[5].columns[0].items[12]" -- Milkshake Chocolate | 160
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001154, 400014001, 400014001006, 50036, 'Milkshake Chocolate', 'milkshake chocolate', NULL, 'MILK SHAKES (WITH ICE CREAM 30/- EXTRA)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60527 (new row in original script) -> existing 50036 'Chocolate Milk Shake'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001161, 400014001154, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001161, 400014001161, 160.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001007: LASSI

-- Source: JSON, "pages[0].sections[6].columns[0].items[0]" -- Salted Lassi / Sweet Lassi | 90
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001155, 400014001, 400014001007, 50136, 'Salted Lassi', 'salted lassi', NULL, 'LASSI', 'veg', NULL, '400014001-P0S6I0', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001162, 400014001155, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001162, 400014001162, 90.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[6].columns[0].items[0]" -- Salted Lassi / Sweet Lassi | 90
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001156, 400014001, 400014001007, 50152, 'Sweet Lassi', 'sweet lassi', NULL, 'LASSI', 'veg', NULL, '400014001-P0S6I0', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001163, 400014001156, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001163, 400014001163, 90.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[6].columns[0].items[1]" -- Mango Lassi / Kesar Lassi | 145
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001157, 400014001, 400014001007, 50102, 'Mango Lassi', 'mango lassi', NULL, 'LASSI', 'veg', NULL, '400014001-P0S6I1', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001164, 400014001157, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001164, 400014001164, 145.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[6].columns[0].items[1]" -- Mango Lassi / Kesar Lassi | 145
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001158, 400014001, 400014001007, 50082, 'Kesar Lassi', 'kesar lassi', NULL, 'LASSI', 'veg', NULL, '400014001-P0S6I1', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001165, 400014001158, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001165, 400014001165, 145.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[6].columns[0].items[2]" -- Shahi Lassi | 145
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001159, 400014001, 400014001007, NULL, 'Shahi Lassi', 'shahi lassi', NULL, 'LASSI', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Shahi Lassi' [was 60528]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001166, 400014001159, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001166, 400014001166, 145.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[6].columns[0].items[3]" -- Chaas | 65
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001160, 400014001, 400014001007, 50033, 'Chaas', 'chaas', NULL, 'LASSI', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001167, 400014001160, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001167, 400014001167, 65.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001008: FALOODA

-- Source: JSON, "pages[0].sections[7].columns[0].items[0]" -- Shubham Spl. Falooda | 210
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001161, 400014001, 400014001008, 60345, 'Shubham Spl. Falooda', 'shubham spl. falooda', NULL, 'FALOODA', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60529 (new row in original script) -> existing 60345 'Special Falooda'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001168, 400014001161, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001168, 400014001168, 210.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[7].columns[0].items[1]" -- Kesar Falooda | 195
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001162, 400014001, 400014001008, 50081, 'Kesar Falooda', 'kesar falooda', NULL, 'FALOODA', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001169, 400014001162, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001169, 400014001169, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[7].columns[0].items[2]" -- Kulfi Falooda | 195
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001163, 400014001, 400014001008, 50089, 'Kulfi Falooda', 'kulfi falooda', NULL, 'FALOODA', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001170, 400014001163, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001170, 400014001170, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[7].columns[0].items[3]" -- Mango Falooda | 210
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001164, 400014001, 400014001008, 50099, 'Mango Falooda', 'mango falooda', NULL, 'FALOODA', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001171, 400014001164, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001171, 400014001171, 210.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[7].columns[0].items[4]" -- Royal Falooda | 185
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001165, 400014001, 400014001008, 50133, 'Royal Falooda', 'royal falooda', NULL, 'FALOODA', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001172, 400014001165, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001172, 400014001172, 185.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001009: JELLY & FRUIT SALAD

-- Source: JSON, "pages[0].sections[8].columns[0].items[0]" -- Plain Jelly | 100
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001166, 400014001, 400014001009, 60116, 'Plain Jelly', 'plain jelly', NULL, 'JELLY & FRUIT SALAD', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001173, 400014001166, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001173, 400014001173, 100.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[8].columns[0].items[1]" -- Ice Cream with Jelly | 148
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001167, 400014001, 400014001009, 60073, 'Ice Cream with Jelly', 'ice cream with jelly', NULL, 'JELLY & FRUIT SALAD', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60530 (new row in original script) -> existing 60073 'JELLY WITH ICE-CREAM'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001174, 400014001167, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001174, 400014001174, 148.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[8].columns[0].items[2]" -- Fruit Salad | 189
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001168, 400014001, 400014001009, 60048, 'Fruit Salad', 'fruit salad', NULL, 'JELLY & FRUIT SALAD', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001175, 400014001168, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001175, 400014001175, 189.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[8].columns[0].items[3]" -- Fruit Salad with Jelly | 210
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001169, 400014001, 400014001009, 60053, 'Fruit Salad with Jelly', 'fruit salad with jelly', NULL, 'JELLY & FRUIT SALAD', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001176, 400014001169, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001176, 400014001176, 210.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[8].columns[0].items[4]" -- Fruit Salad with Jelly & Ice Cream | 245
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001170, 400014001, 400014001009, 60054, 'Fruit Salad with Jelly & Ice Cream', 'fruit salad with jelly & ice cream', NULL, 'JELLY & FRUIT SALAD', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001177, 400014001170, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001177, 400014001177, 245.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001010: HOT BEVERAGES

-- Source: JSON, "pages[0].sections[9].columns[0].items[0]" -- Tea | 39
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001171, 400014001, 400014001010, 50154, 'Tea', 'tea', NULL, 'HOT BEVERAGES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001178, 400014001171, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001178, 400014001178, 39.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[9].columns[0].items[1]" -- Special Tea | 53
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001172, 400014001, 400014001010, 50145, 'Special Tea', 'special tea', NULL, 'HOT BEVERAGES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001179, 400014001172, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001179, 400014001179, 53.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[9].columns[0].items[2]" -- Filter Coffee | 58
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001173, 400014001, 400014001010, 50057, 'Filter Coffee', 'filter coffee', NULL, 'HOT BEVERAGES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001180, 400014001173, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001180, 400014001180, 58.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[9].columns[0].items[3]" -- Nescafe | 63
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001174, 400014001, 400014001010, 13622, 'Nescafe', 'nescafe', NULL, 'HOT BEVERAGES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001181, 400014001174, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001181, 400014001181, 63.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[9].columns[0].items[4]" -- Bournvita | 80
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001175, 400014001, 400014001010, 60353, 'Bournvita', 'bournvita', NULL, 'HOT BEVERAGES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001182, 400014001175, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001182, 400014001182, 80.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[9].columns[0].items[5]" -- Milk | 50
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001176, 400014001, 400014001010, 50109, 'Milk', 'milk', NULL, 'HOT BEVERAGES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001183, 400014001176, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001183, 400014001183, 50.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001011: COLD BEVERAGES

-- Source: JSON, "pages[0].sections[10].columns[0].items[0]" -- Cold Coffee | 140
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001177, 400014001, 400014001011, 50040, 'Cold Coffee', 'cold coffee', NULL, 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001184, 400014001177, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001184, 400014001184, 140.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[10].columns[0].items[1]" -- Cold Drinks | 30
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001178, 400014001, 400014001011, 50002, 'Cold Drinks', 'cold drinks', NULL, 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60531 (new row in original script) -> existing 50002 'ALL COLD DRINKS'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001185, 400014001178, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001185, 400014001185, 30.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[10].columns[0].items[2]" -- Half Litre Cold Drink (500ml) | 60
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001179, 400014001, 400014001011, 50002, 'Half Litre Cold Drink (500ml)', 'half litre cold drink (500ml)', NULL, 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60532 (new row in original script) -> existing 50002 'ALL COLD DRINKS'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001186, 400014001179, 'Regular', 'fixed', 500, 'ml', 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001186, 400014001186, 60.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[10].columns[0].items[3]" -- Soda | 45
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001180, 400014001, 400014001011, 50142, 'Soda', 'soda', NULL, 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001187, 400014001180, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001187, 400014001187, 45.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[10].columns[0].items[4]" -- Can | 70
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001181, 400014001, 400014001011, 50002, 'Can', 'can', NULL, 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60533 (new row in original script) -> existing 50002 'ALL COLD DRINKS'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001188, 400014001181, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001188, 400014001188, 70.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[10].columns[0].items[5]" -- Fresh Lime Soda Sweet / Salt | 75
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001182, 400014001, 400014001011, 50061, 'Fresh Lime Soda Sweet / Salt', 'fresh lime soda sweet / salt', NULL, 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60534 (new row in original script) -> existing 50061 'Fresh Lime Soda'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001189, 400014001182, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001189, 400014001189, 75.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[10].columns[0].items[6]" -- Fresh Lime Juice | 50
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001183, 400014001, 400014001011, 50060, 'Fresh Lime Juice', 'fresh lime juice', NULL, 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001190, 400014001183, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001190, 400014001190, 50.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[10].columns[0].items[7]" -- Jaljeera | 85
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001184, 400014001, 400014001011, NULL, 'Jaljeera', 'jaljeera', NULL, 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Jaljeera' [was 60535]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001191, 400014001184, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001191, 400014001191, 85.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[10].columns[0].items[8]" -- Sikandari Sharbat / Ginger Lemon | 90
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001185, 400014001, 400014001011, 50138, 'Sikandari Sharbat', 'sikandari sharbat', NULL, 'COLD BEVERAGES', 'veg', NULL, '400014001-P0S10I8', 'unverified');  -- canonical_dish_id: was 60536 (new row in original script) -> existing 50138 'Sikandar Sharbat'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001192, 400014001185, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001192, 400014001192, 90.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[10].columns[0].items[8]" -- Sikandari Sharbat / Ginger Lemon | 90
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001186, 400014001, 400014001011, 13331, 'Ginger Lemon', 'ginger lemon', NULL, 'COLD BEVERAGES', 'veg', NULL, '400014001-P0S10I8', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001193, 400014001186, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001193, 400014001193, 90.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[10].columns[0].items[9]" -- Packaged Drinking Water | 13 / 26
-- REVIEW: two prices (13 / 26) but no size labels or legend; variant kept as raw text with NO price row rather than guessing which price is which; no price row created: 13 and 26 cannot be assigned to sizes without labels (raw text kept in variant_name)
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001187, 400014001, 400014001011, NULL, 'Packaged Drinking Water', 'packaged drinking water', NULL, 'COLD BEVERAGES', 'veg', NULL, NULL, 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001194, 400014001187, '13 / 26 (unclear)', 'fixed', NULL, NULL, 1, TRUE);
-- (no price row: price unclear in JSON, see REVIEW note)

-- ---- CATEGORY 400014001012: ICECREAM / DESSERTS

-- Source: JSON, "pages[0].sections[11].columns[0].items[0]" -- Vanila Big (Scoop) | 60
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001188, 400014001, 400014001012, 40035, 'Vanila Big (Scoop)', 'vanila big (scoop)', NULL, 'ICECREAM / DESSERTS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60537 (new row in original script) -> existing 40035 'Vanilla'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001195, 400014001188, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001194, 400014001195, 60.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[11].columns[0].items[1]" -- Strawberry (Scoop) | 60
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001189, 400014001, 400014001012, 60143, 'Strawberry (Scoop)', 'strawberry (scoop)', NULL, 'ICECREAM / DESSERTS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60538 (new row in original script) -> existing 60143 'Strawberry'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001196, 400014001189, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001195, 400014001196, 60.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[11].columns[0].items[2]" -- Kesar Pista (Scoop) | 72
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001190, 400014001, 400014001012, 13430, 'Kesar Pista (Scoop)', 'kesar pista (scoop)', NULL, 'ICECREAM / DESSERTS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60539 (new row in original script) -> existing 13430 'Keser Pista'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001197, 400014001190, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001196, 400014001197, 72.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[11].columns[0].items[3]" -- Kesar Kishmish | 72
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001191, 400014001, 400014001012, NULL, 'Kesar Kishmish', 'kesar kishmish', NULL, 'ICECREAM / DESSERTS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Kesar Kishmish' [was 60540]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001198, 400014001191, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001197, 400014001198, 72.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[11].columns[0].items[4]" -- Butter Scotch (Scoop) | 72
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001192, 400014001, 400014001012, 40005, 'Butter Scotch (Scoop)', 'butter scotch (scoop)', NULL, 'ICECREAM / DESSERTS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60541 (new row in original script) -> existing 40005 'Butter Scotch'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001199, 400014001192, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001198, 400014001199, 72.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[11].columns[0].items[5]" -- Cassata Slice | 120
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001193, 400014001, 400014001012, 13121, 'Cassata Slice', 'cassata slice', NULL, 'ICECREAM / DESSERTS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60542 (new row in original script) -> existing 13121 'Casatta'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001200, 400014001193, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001199, 400014001200, 120.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[11].columns[0].items[6]" -- Chocolate | 72
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001194, 400014001, 400014001012, 13175, 'Chocolate', 'chocolate', NULL, 'ICECREAM / DESSERTS', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001201, 400014001194, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001200, 400014001201, 72.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[11].columns[0].items[7]" -- Mango | 72
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001195, 400014001, 400014001012, 60085, 'Mango', 'mango', NULL, 'ICECREAM / DESSERTS', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001202, 400014001195, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001201, 400014001202, 72.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001013: KULFI

-- Source: JSON, "pages[0].sections[12].columns[0].items[0]" -- Malai | 100
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001196, 400014001, 400014001013, 40023, 'Malai', 'malai', NULL, 'KULFI', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60543 (new row in original script) -> existing 40023 'Malai Kulfi'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001203, 400014001196, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001202, 400014001203, 100.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[12].columns[0].items[1]" -- Badam Pista / Kesar Pista | 110
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001197, 400014001, 400014001013, 13059, 'Badam Pista', 'badam pista', NULL, 'KULFI', 'veg', NULL, '400014001-P0S12I1', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001204, 400014001197, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001203, 400014001204, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[0].sections[12].columns[0].items[1]" -- Badam Pista / Kesar Pista | 110
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001198, 400014001, 400014001013, 40022, 'Kesar Pista', 'kesar pista', NULL, 'KULFI', 'veg', NULL, '400014001-P0S12I1', 'unverified');  -- canonical_dish_id: was 60544 (new row in original script) -> existing 40022 'KESAR PISTA KULFI'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001205, 400014001198, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001204, 400014001205, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001014: SOUTH INDIAN SNACKS

-- Source: JSON, "pages[1].sections[0].columns[0].items[0]" -- Steam Idli / Butter Idli | 75 / 105
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001199, 400014001, 400014001014, 10777, 'Steam Idli', 'steam idli', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, '400014001-P1S0I0', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001206, 400014001199, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001205, 400014001206, 75.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[0]" -- Steam Idli / Butter Idli | 75 / 105
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001200, 400014001, 400014001014, 10080, 'Butter Idli', 'butter idli', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, '400014001-P1S0I0', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001207, 400014001200, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001206, 400014001207, 105.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[1]" -- Idli Fry | 110
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001201, 400014001, 400014001014, 10327, 'Idli Fry', 'idli fry', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001208, 400014001201, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001207, 400014001208, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[2]" -- Tawa Idli (After 11) | 165
-- REVIEW: "(After 11)" read as available from 11:00 (a.m.) onwards, no end time; JSON does not say a.m./p.m.
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001202, 400014001, 400014001014, 10794, 'Tawa Idli', 'tawa idli', '(After 11)', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001209, 400014001202, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001208, 400014001209, 165.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[3]" -- Dahi Idli / Dahi Wada | 110
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001203, 400014001, 400014001014, 10225, 'Dahi Idli', 'dahi idli', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, '400014001-P1S0I3', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001210, 400014001203, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001209, 400014001210, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[3]" -- Dahi Idli / Dahi Wada | 110
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001204, 400014001, 400014001014, 10229, 'Dahi Wada', 'dahi wada', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, '400014001-P1S0I3', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001211, 400014001204, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001210, 400014001211, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[4]" -- Medu Wada | 92
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001205, 400014001, 400014001014, 10446, 'Medu Wada', 'medu wada', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001212, 400014001205, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001211, 400014001212, 92.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[5]" -- Idli Wada Mix | 92
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001206, 400014001, 400014001014, 10330, 'Idli Wada Mix', 'idli wada mix', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60545 (new row in original script) -> existing 10330 'IDLI VADA MIX'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001213, 400014001206, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001212, 400014001213, 92.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[6]" -- Mix Wada (Batata + Medu Wada) | 92
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001207, 400014001, 400014001014, 10460, 'Mix Wada (Batata + Medu Wada)', 'mix wada (batata + medu wada)', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60546 (new row in original script) -> existing 10460 'Mix Vada'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001214, 400014001207, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001213, 400014001214, 92.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[7]" -- Usal / Usal Pav | 77 / 90
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001208, 400014001, 400014001014, NULL, 'Usal', 'usal', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, '400014001-P1S0I7', 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Usal' [was 60547]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001215, 400014001208, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001214, 400014001215, 77.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[7]" -- Usal / Usal Pav | 77 / 90
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001209, 400014001, 400014001014, 10822, 'Usal Pav', 'usal pav', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, '400014001-P1S0I7', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001216, 400014001209, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001215, 400014001216, 90.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[8]" -- Batata Wada | 92
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001210, 400014001, 400014001014, 10061, 'Batata Wada', 'batata wada', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60548 (new row in original script) -> existing 10061 'Batata Vada'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001217, 400014001210, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001216, 400014001217, 92.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[9]" -- Batata Wada Usal | 130
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001211, 400014001, 400014001014, 10826, 'Batata Wada Usal', 'batata wada usal', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60549 (new row in original script) -> existing 10826 'Vada Usal (Potato)'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001218, 400014001211, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001217, 400014001218, 130.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[10]" -- Dahi Misal / Dahi Misal Pav | 120 / 130
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001212, 400014001, 400014001014, NULL, 'Dahi Misal', 'dahi misal', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, '400014001-P1S0I10', 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Dahi Misal' [was 60550]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001219, 400014001212, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001218, 400014001219, 120.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[10]" -- Dahi Misal / Dahi Misal Pav | 120 / 130
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001213, 400014001, 400014001014, 10227, 'Dahi Misal Pav', 'dahi misal pav', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, '400014001-P1S0I10', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001220, 400014001213, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001219, 400014001220, 130.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[11]" -- Only Misal | 92
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001214, 400014001, 400014001014, 60408, 'Only Misal', 'only misal', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60551 (new row in original script) -> existing 60408 'Misal'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001221, 400014001214, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001220, 400014001221, 92.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[12]" -- Misal Pav (2 Pcs) | 105
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001215, 400014001, 400014001014, 10456, 'Misal Pav (2 Pcs)', 'misal pav (2 pcs)', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60552 (new row in original script) -> existing 10456 'Misal Pav'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001222, 400014001215, 'Regular', 'fixed', 2, 'pieces', 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001221, 400014001222, 105.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[13]" -- Punjabi Samosa / Veg Cutlet | 92
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001216, 400014001, 400014001014, 60413, 'Punjabi Samosa', 'punjabi samosa', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, '400014001-P1S0I13', 'unverified');  -- canonical_dish_id: was 60553 (new row in original script) -> existing 60413 'P. Samosa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001223, 400014001216, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001222, 400014001223, 92.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[13]" -- Punjabi Samosa / Veg Cutlet | 92
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001217, 400014001, 400014001014, 10872, 'Veg Cutlet', 'veg cutlet', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, '400014001-P1S0I13', 'unverified');  -- canonical_dish_id: was 60554 (new row in original script) -> existing 10872 'Veg. Cutlet'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001224, 400014001217, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001223, 400014001224, 92.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[14]" -- Upma / Sheera (Only Morning) | 75 / 80
-- REVIEW: "(Only Morning)" applies to both Upma and Sheera but JSON gives no hours; kept as description, NO availability row created
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001218, 400014001, 400014001014, 13879, 'Upma', 'upma', '(Only Morning)', 'SOUTH INDIAN SNACKS', 'veg', NULL, '400014001-P1S0I14', 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001225, 400014001218, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001224, 400014001225, 75.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[14]" -- Upma / Sheera (Only Morning) | 75 / 80
-- REVIEW: "(Only Morning)" applies to both Upma and Sheera but JSON gives no hours; kept as description, NO availability row created
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001219, 400014001, 400014001014, 60134, 'Sheera', 'sheera', '(Only Morning)', 'SOUTH INDIAN SNACKS', 'veg', NULL, '400014001-P1S0I14', 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001226, 400014001219, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001225, 400014001226, 80.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[0].columns[0].items[15]" -- Kanda Poha | 75
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001220, 400014001, 400014001014, 10377, 'Kanda Poha', 'kanda poha', NULL, 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60555 (new row in original script) -> existing 10377 'KANDA POHA (ONLY MORNING)'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001227, 400014001220, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001226, 400014001227, 75.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001015: DOSA'S

-- Source: JSON, "pages[1].sections[1].columns[0].items[0]" -- Sada Dosa | 105
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001221, 400014001, 400014001015, 10726, 'Sada Dosa', 'sada dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001228, 400014001221, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001227, 400014001228, 105.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[1]" -- Sada Dosa Butter / Cheese | 130 / 145
-- REVIEW: name expanded from shortened source line "Sada Dosa Butter / Cheese"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001222, 400014001, 400014001015, 10087, 'Sada Dosa Butter', 'sada dosa butter', NULL, 'DOSA''S', 'veg', NULL, '400014001-P1S1I1', 'needs_review');  -- canonical_dish_id: was 60556 (new row in original script) -> existing 10087 'Butter Sada Dosa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001229, 400014001222, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001228, 400014001229, 130.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[1]" -- Sada Dosa Butter / Cheese | 130 / 145
-- REVIEW: name expanded from shortened source line "Sada Dosa Butter / Cheese"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001223, 400014001, 400014001015, 10166, 'Sada Dosa Cheese', 'sada dosa cheese', NULL, 'DOSA''S', 'veg', NULL, '400014001-P1S1I1', 'needs_review');  -- canonical_dish_id: was 60557 (new row in original script) -> existing 10166 'Cheese Sada Dosa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001230, 400014001223, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001229, 400014001230, 145.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[2]" -- Masala Dosa | 115
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001224, 400014001, 400014001015, 10421, 'Masala Dosa', 'masala dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001231, 400014001224, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001230, 400014001231, 115.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[3]" -- Butter Masala Dosa | 145
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001225, 400014001, 400014001015, 10065, 'Butter Masala Dosa', 'butter masala dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60558 (new row in original script) -> existing 10065 'BENNE MASALA DOSA'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001232, 400014001225, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001231, 400014001232, 145.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[4]" -- Cheese Masala Dosa | 160
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001226, 400014001, 400014001015, 10138, 'Cheese Masala Dosa', 'cheese masala dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001233, 400014001226, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001232, 400014001233, 160.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[5]" -- Mysore Sada | 115
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001227, 400014001, 400014001015, 10500, 'Mysore Sada', 'mysore sada', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60559 (new row in original script) -> existing 10500 'Mysore Sada Dosa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001234, 400014001227, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001233, 400014001234, 115.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[6]" -- Butter Mysore Sada | 150
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001228, 400014001, 400014001015, NULL, 'Butter Mysore Sada', 'butter mysore sada', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Butter Mysore Sada' [was 60560]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001235, 400014001228, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001234, 400014001235, 150.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[7]" -- Cheese Mysore Sada | 165
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001229, 400014001, 400014001015, 10148, 'Cheese Mysore Sada', 'cheese mysore sada', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60561 (new row in original script) -> existing 10148 'Cheese Mysore Sada Dosa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001236, 400014001229, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001235, 400014001236, 165.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[8]" -- Mysore Masala | 125
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001230, 400014001, 400014001015, 10493, 'Mysore Masala', 'mysore masala', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60562 (new row in original script) -> existing 10493 'Mysore Masala Dosa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001237, 400014001230, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001236, 400014001237, 125.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[9]" -- Butter Mysore Masala | 160
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001231, 400014001, 400014001015, NULL, 'Butter Mysore Masala', 'butter mysore masala', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Butter Mysore Masala' [was 60563]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001238, 400014001231, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001237, 400014001238, 160.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[10]" -- Cheese Mysore Masala | 175
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001232, 400014001, 400014001015, 10146, 'Cheese Mysore Masala', 'cheese mysore masala', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60564 (new row in original script) -> existing 10146 'Cheese Mysore Masala Dosa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001239, 400014001232, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001238, 400014001239, 175.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[11]" -- Rawa Sada | 125
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001233, 400014001, 400014001015, 10711, 'Rawa Sada', 'rawa sada', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60565 (new row in original script) -> existing 10711 'Rawa Sada Dosa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001240, 400014001233, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001239, 400014001240, 125.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[12]" -- Butter Rawa Sada | 150
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001234, 400014001, 400014001015, NULL, 'Butter Rawa Sada', 'butter rawa sada', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Butter Rawa Sada' [was 60566]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001241, 400014001234, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001240, 400014001241, 150.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[13]" -- Cheese Rawa Sada | 170
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001235, 400014001, 400014001015, NULL, 'Cheese Rawa Sada', 'cheese rawa sada', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Cheese Rawa Sada' [was 60567]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001242, 400014001235, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001241, 400014001242, 170.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[14]" -- Rawa Masala | 135
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001236, 400014001, 400014001015, 10710, 'Rawa Masala', 'rawa masala', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60568 (new row in original script) -> existing 10710 'RAWA MASALA DOSA'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001243, 400014001236, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001242, 400014001243, 135.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[15]" -- Butter Rawa Masala | 165
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001237, 400014001, 400014001015, NULL, 'Butter Rawa Masala', 'butter rawa masala', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Butter Rawa Masala' [was 60569]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001244, 400014001237, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001243, 400014001244, 165.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[16]" -- Cheese Rawa Masala | 190
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001238, 400014001, 400014001015, NULL, 'Cheese Rawa Masala', 'cheese rawa masala', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Cheese Rawa Masala' [was 60570]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001245, 400014001238, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001244, 400014001245, 190.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[17]" -- Onion Rawa Sada | 140
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001239, 400014001, 400014001015, 10524, 'Onion Rawa Sada', 'onion rawa sada', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60571 (new row in original script) -> existing 10524 'Onion Rawa Sada Dosa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001246, 400014001239, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001245, 400014001246, 140.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[18]" -- Butter Onion Rawa Sada | 160
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001240, 400014001, 400014001015, NULL, 'Butter Onion Rawa Sada', 'butter onion rawa sada', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Butter Onion Rawa Sada' [was 60572]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001247, 400014001240, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001246, 400014001247, 160.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[19]" -- Cheese Onion Rawa Sada | 185
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001241, 400014001, 400014001015, NULL, 'Cheese Onion Rawa Sada', 'cheese onion rawa sada', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Cheese Onion Rawa Sada' [was 60573]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001248, 400014001241, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001247, 400014001248, 185.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[20]" -- Onion Rawa Masala | 145
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001242, 400014001, 400014001015, 10523, 'Onion Rawa Masala', 'onion rawa masala', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60574 (new row in original script) -> existing 10523 'ONION RAWA MASALA DOSA'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001249, 400014001242, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001248, 400014001249, 145.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[21]" -- Butter Onion Rawa Masala | 170
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001243, 400014001, 400014001015, NULL, 'Butter Onion Rawa Masala', 'butter onion rawa masala', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Butter Onion Rawa Masala' [was 60575]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001250, 400014001243, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001249, 400014001250, 170.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[22]" -- Cheese Onion Rawa Masala | 195
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001244, 400014001, 400014001015, NULL, 'Cheese Onion Rawa Masala', 'cheese onion rawa masala', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Cheese Onion Rawa Masala' [was 60576]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001251, 400014001244, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001250, 400014001251, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[23]" -- Rawa Mysore Sada | 150
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001245, 400014001, 400014001015, 10499, 'Rawa Mysore Sada', 'rawa mysore sada', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60577 (new row in original script) -> existing 10499 'MYSORE RAWA SADA DOSA'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001252, 400014001245, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001251, 400014001252, 150.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[24]" -- Rawa Mysore Masala | 250
-- REVIEW: price 250 is ~100 above its siblings (Rawa Mysore Sada 150; Butter/Cheese variants run +10..+25); possible misprint
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001246, 400014001, 400014001015, 10498, 'Rawa Mysore Masala', 'rawa mysore masala', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60578 (new row in original script) -> existing 10498 'MYSORE RAWA MASALA DOSA'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001253, 400014001246, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001252, 400014001253, 250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review');

-- Source: JSON, "pages[1].sections[1].columns[0].items[25]" -- Paper Dosa / Paper Masala | 199 / 230
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001247, 400014001, 400014001015, 10654, 'Paper Dosa', 'paper dosa', NULL, 'DOSA''S', 'veg', NULL, '400014001-P1S1I25', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001254, 400014001247, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001253, 400014001254, 199.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[25]" -- Paper Dosa / Paper Masala | 199 / 230
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001248, 400014001, 400014001015, 13668, 'Paper Masala', 'paper masala', NULL, 'DOSA''S', 'veg', NULL, '400014001-P1S1I25', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001255, 400014001248, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001254, 400014001255, 230.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[26]" -- Shubham Special Dosa | 250
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001249, 400014001, 400014001015, NULL, 'Shubham Special Dosa', 'shubham special dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Shubham Special Dosa' [was 60579]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001256, 400014001249, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001255, 400014001256, 250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[27]" -- Triple Decker Dosa | 260
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001250, 400014001, 400014001015, NULL, 'Triple Decker Dosa', 'triple decker dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Triple Decker Dosa' [was 60580]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001257, 400014001250, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001256, 400014001257, 260.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[28]" -- Paneer Cheese Dosa | 200
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001251, 400014001, 400014001015, NULL, 'Paneer Cheese Dosa', 'paneer cheese dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Paneer Cheese Dosa' [was 60581]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001258, 400014001251, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001257, 400014001258, 200.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[29]" -- Anand Dosa | 200
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001252, 400014001, 400014001015, NULL, 'Anand Dosa', 'anand dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Anand Dosa' [was 60582]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001259, 400014001252, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001258, 400014001259, 200.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[30]" -- Palak Dosa | 215
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001253, 400014001, 400014001015, 13652, 'Palak Dosa', 'palak dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001260, 400014001253, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001259, 400014001260, 215.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[31]" -- Cheese Palak Dosa | 235
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001254, 400014001, 400014001015, NULL, 'Cheese Palak Dosa', 'cheese palak dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Cheese Palak Dosa' [was 60583]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001261, 400014001254, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001260, 400014001261, 235.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[32]" -- Set Dosa | 245
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001255, 400014001, 400014001015, 10754, 'Set Dosa', 'set dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001262, 400014001255, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001261, 400014001262, 245.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[33]" -- Spring Dosa / Manchurian Dosa | 190
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001256, 400014001, 400014001015, 10773, 'Spring Dosa', 'spring dosa', NULL, 'DOSA''S', 'veg', NULL, '400014001-P1S1I33', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001263, 400014001256, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001262, 400014001263, 190.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[33]" -- Spring Dosa / Manchurian Dosa | 190
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001257, 400014001, 400014001015, NULL, 'Manchurian Dosa', 'manchurian dosa', NULL, 'DOSA''S', 'veg', NULL, '400014001-P1S1I33', 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Manchurian Dosa' [was 60584]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001264, 400014001257, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001263, 400014001264, 190.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[34]" -- Chopsuey Dosa / Chilly Dosa | 190
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001258, 400014001, 400014001015, NULL, 'Chopsuey Dosa', 'chopsuey dosa', NULL, 'DOSA''S', 'veg', NULL, '400014001-P1S1I34', 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Chopsuey Dosa' [was 60585]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001265, 400014001258, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001264, 400014001265, 190.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[34]" -- Chopsuey Dosa / Chilly Dosa | 190
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001259, 400014001, 400014001015, 10179, 'Chilly Dosa', 'chilly dosa', NULL, 'DOSA''S', 'veg', NULL, '400014001-P1S1I34', 'unverified');  -- canonical_dish_id: was 60586 (new row in original script) -> existing 10179 'CHILLI DOSA'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001266, 400014001259, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001265, 400014001266, 190.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[35]" -- Schezwan Sada Dosa | 155
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001260, 400014001, 400014001015, 10747, 'Schezwan Sada Dosa', 'schezwan sada dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001267, 400014001260, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001266, 400014001267, 155.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[1].columns[0].items[36]" -- Schezwan Cheese Sada Dosa | 120
-- REVIEW: price 120 is below Schezwan Sada Dosa 155 although the cheese version normally costs more; possible misprint
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001261, 400014001, 400014001015, 10751, 'Schezwan Cheese Sada Dosa', 'schezwan cheese sada dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60587 (new row in original script) -> existing 10751 'Schzewan Cheese Sada Dosa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001268, 400014001261, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001267, 400014001268, 120.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review');

-- Source: JSON, "pages[1].sections[1].columns[0].items[37]" -- Coconut Dosa | 140
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001262, 400014001, 400014001015, 10781, 'Coconut Dosa', 'coconut dosa', NULL, 'DOSA''S', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60588 (new row in original script) -> existing 10781 'SWEET COCONUT DOSA'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001269, 400014001262, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001268, 400014001269, 140.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001016: UTTAPPAS

-- Source: JSON, "pages[1].sections[2].columns[0].items[0]" -- Spl. Uttappa | 185
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001263, 400014001, 400014001016, NULL, 'Spl. Uttappa', 'spl. uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Spl. Uttappa' [was 60589]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001270, 400014001263, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001269, 400014001270, 185.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[1]" -- Uttappa Plain | 120
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001264, 400014001, 400014001016, 10823, 'Uttappa Plain', 'uttappa plain', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60590 (new row in original script) -> existing 10823 'Uttapam Plain'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001271, 400014001264, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001270, 400014001271, 120.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[2]" -- Butter Uttappa | 150
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001265, 400014001, 400014001016, 10088, 'Butter Uttappa', 'butter uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60591 (new row in original script) -> existing 10088 'Butter Uttappam'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001272, 400014001265, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001271, 400014001272, 150.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[3]" -- Cheese Uttappa | 165
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001266, 400014001, 400014001016, 10174, 'Cheese Uttappa', 'cheese uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60592 (new row in original script) -> existing 10174 'Cheese Uttappam'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001273, 400014001266, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001272, 400014001273, 165.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[4]" -- Onion Uttappa | 130
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001267, 400014001, 400014001016, 10529, 'Onion Uttappa', 'onion uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60593 (new row in original script) -> existing 10529 'Onion Uttapa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001274, 400014001267, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001273, 400014001274, 130.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[5]" -- Butter Onion Uttappa | 165
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001268, 400014001, 400014001016, 10084, 'Butter Onion Uttappa', 'butter onion uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60594 (new row in original script) -> existing 10084 'Butter Onion Uttappam'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001275, 400014001268, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001274, 400014001275, 165.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[6]" -- Cheese Onion Uttappa | 180
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001269, 400014001, 400014001016, 10152, 'Cheese Onion Uttappa', 'cheese onion uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60595 (new row in original script) -> existing 10152 'Cheese Onion Uttapa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001276, 400014001269, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001275, 400014001276, 180.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[7]" -- Tomato Uttappa | 130
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001270, 400014001, 400014001016, 10813, 'Tomato Uttappa', 'tomato uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60596 (new row in original script) -> existing 10813 'Tomato Uttapa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001277, 400014001270, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001276, 400014001277, 130.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[8]" -- Butter Tomato Uttappa | 165
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001271, 400014001, 400014001016, NULL, 'Butter Tomato Uttappa', 'butter tomato uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Butter Tomato Uttappa' [was 60597]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001278, 400014001271, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001277, 400014001278, 165.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[9]" -- Cheese Tomato Uttappa | 180
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001272, 400014001, 400014001016, 10172, 'Cheese Tomato Uttappa', 'cheese tomato uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60598 (new row in original script) -> existing 10172 'Cheese Tomato Uttapa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001279, 400014001272, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001278, 400014001279, 180.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[10]" -- Onion Tomato Uttappa | 145
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001273, 400014001, 400014001016, 10527, 'Onion Tomato Uttappa', 'onion tomato uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60599 (new row in original script) -> existing 10527 'Onion Tomato Uttapa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001280, 400014001273, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001279, 400014001280, 145.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[11]" -- Butter Tomato Onion Uttappa | 180
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001274, 400014001, 400014001016, NULL, 'Butter Tomato Onion Uttappa', 'butter tomato onion uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Butter Tomato Onion Uttappa' [was 60600]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001281, 400014001274, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001280, 400014001281, 180.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[12]" -- Cheese Tomato Onion Uttappa | 195
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001275, 400014001, 400014001016, NULL, 'Cheese Tomato Onion Uttappa', 'cheese tomato onion uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Cheese Tomato Onion Uttappa' [was 60601]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001282, 400014001275, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001281, 400014001282, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[13]" -- Coconut Uttappa | 160
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001276, 400014001, 400014001016, 10207, 'Coconut Uttappa', 'coconut uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001283, 400014001276, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001282, 400014001283, 160.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[14]" -- Cheese Coconut Uttappa | 199
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001277, 400014001, 400014001016, NULL, 'Cheese Coconut Uttappa', 'cheese coconut uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Cheese Coconut Uttappa' [was 60602]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001284, 400014001277, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001283, 400014001284, 199.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[15]" -- Paneer Uttappa | 185
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001278, 400014001, 400014001016, 10643, 'Paneer Uttappa', 'paneer uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001285, 400014001278, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001284, 400014001285, 185.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[16]" -- Cheese Paneer Uttappa | 225
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001279, 400014001, 400014001016, 10645, 'Cheese Paneer Uttappa', 'cheese paneer uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60603 (new row in original script) -> existing 10645 'Panner Cheese Sada Uttapa'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001286, 400014001279, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001285, 400014001286, 225.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[17]" -- Tomato Omlet | 165
-- REVIEW: name suggests egg ("Omlet") but restaurant is declared pure vegetarian (JSON pure_veg=true); classified veg - confirm it is the eggless tomato omelette
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001280, 400014001, 400014001016, 15045, 'Tomato Omlet', 'tomato omlet', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'needs_review');  -- canonical_dish_id: was 60604 (new row in original script) -> existing 15045 'Tomato Omelette'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001287, 400014001280, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001286, 400014001287, 165.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[18]" -- Butter Palak Uttappa | 175
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001281, 400014001, 400014001016, NULL, 'Butter Palak Uttappa', 'butter palak uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Butter Palak Uttappa' [was 60605]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001288, 400014001281, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001287, 400014001288, 175.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[19]" -- Cheese Palak Uttappa | 195
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001282, 400014001, 400014001016, NULL, 'Cheese Palak Uttappa', 'cheese palak uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Cheese Palak Uttappa' [was 60606]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001289, 400014001282, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001288, 400014001289, 195.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[20]" -- Masala Uttappa | 175
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001283, 400014001, 400014001016, 10432, 'Masala Uttappa', 'masala uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001290, 400014001283, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001289, 400014001290, 175.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[2].columns[0].items[21]" -- Butter Pineapple Uttappa | 190
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001284, 400014001, 400014001016, NULL, 'Butter Pineapple Uttappa', 'butter pineapple uttappa', NULL, 'UTTAPPAS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Butter Pineapple Uttappa' [was 60607]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001291, 400014001284, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001290, 400014001291, 190.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001017: FASTING ITEM

-- Source: JSON, "pages[1].sections[3].columns[0].items[0]" -- Sabudana Wada | 105
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001285, 400014001, 400014001017, 10722, 'Sabudana Wada', 'sabudana wada', NULL, 'FASTING ITEM', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001292, 400014001285, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001291, 400014001292, 105.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[3].columns[0].items[1]" -- Sweet Kachori | 105
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001286, 400014001, 400014001017, 10783, 'Sweet Kachori', 'sweet kachori', NULL, 'FASTING ITEM', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001293, 400014001286, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001292, 400014001293, 105.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[3].columns[0].items[2]" -- Finger Chips | 110
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001287, 400014001, 400014001017, 10253, 'Finger Chips', 'finger chips', NULL, 'FASTING ITEM', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001294, 400014001287, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001293, 400014001294, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[3].columns[0].items[3]" -- Sabudana Khichadi | 105
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001288, 400014001, 400014001017, 13727, 'Sabudana Khichadi', 'sabudana khichadi', NULL, 'FASTING ITEM', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60608 (new row in original script) -> existing 13727 'Sabudana Khichdi'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001295, 400014001288, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001294, 400014001295, 105.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[3].columns[0].items[4]" -- Upwas Pattice | 120
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001289, 400014001, 400014001017, NULL, 'Upwas Pattice', 'upwas pattice', NULL, 'FASTING ITEM', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Upwas Pattice' [was 60609]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001296, 400014001289, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001295, 400014001296, 120.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[3].columns[0].items[5]" -- Rajgiri Puri Bhaji | 130
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001290, 400014001, 400014001017, NULL, 'Rajgiri Puri Bhaji', 'rajgiri puri bhaji', NULL, 'FASTING ITEM', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Rajgiri Puri Bhaji' [was 60610]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001297, 400014001290, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001296, 400014001297, 130.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001018: SWEET

-- Source: JSON, "pages[1].sections[4].columns[0].items[0]" -- Kheer | 140
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001291, 400014001, 400014001018, NULL, 'Kheer', 'kheer', NULL, 'SWEET', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Kheer' [was 60611]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001298, 400014001291, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001297, 400014001298, 140.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[4].columns[0].items[1]" -- Gulab Jamun | 85
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001292, 400014001, 400014001018, 60062, 'Gulab Jamun', 'gulab jamun', NULL, 'SWEET', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001299, 400014001292, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001298, 400014001299, 85.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[4].columns[0].items[2]" -- Matka Rabdi | 160
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001293, 400014001, 400014001018, 60098, 'Matka Rabdi', 'matka rabdi', NULL, 'SWEET', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001300, 400014001293, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001299, 400014001300, 160.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[4].columns[0].items[3]" -- Custard | 105
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001294, 400014001, 400014001018, NULL, 'Custard', 'custard', NULL, 'SWEET', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Custard' [was 60612]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001301, 400014001294, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001300, 400014001301, 105.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001019: PURI WITH

-- Source: JSON, "pages[1].sections[5].columns[0].items[0]" -- Puri Bhaji | 115
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001295, 400014001, 400014001019, 23092, 'Puri Bhaji', 'puri bhaji', NULL, 'PURI WITH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001302, 400014001295, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001301, 400014001302, 115.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[5].columns[0].items[1]" -- Puri Shrikhand | 135
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001296, 400014001, 400014001019, 23093, 'Puri Shrikhand', 'puri shrikhand', NULL, 'PURI WITH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001303, 400014001296, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001302, 400014001303, 135.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[5].columns[0].items[2]" -- Seasonal Only Aam Ras | 155
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001297, 400014001, 400014001019, NULL, 'Seasonal Only Aam Ras', 'seasonal only aam ras', NULL, 'PURI WITH', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Seasonal Only Aam Ras' [was 60613]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001304, 400014001297, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001303, 400014001304, 155.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[5].columns[0].items[3]" -- Aam Ras Puri (Seasonal) | 180
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001298, 400014001, 400014001019, NULL, 'Aam Ras Puri (Seasonal)', 'aam ras puri (seasonal)', NULL, 'PURI WITH', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Aam Ras Puri (Seasonal)' [was 60614]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001305, 400014001298, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001304, 400014001305, 180.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[5].columns[0].items[4]" -- Extra Puri / Extra Rice | 90
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001299, 400014001, 400014001019, NULL, 'Extra Puri', 'extra puri', NULL, 'PURI WITH', 'veg', NULL, '400014001-P1S5I4', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001306, 400014001299, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001305, 400014001306, 90.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[5].columns[0].items[4]" -- Extra Puri / Extra Rice | 90
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001300, 400014001, 400014001019, NULL, 'Extra Rice', 'extra rice', NULL, 'PURI WITH', 'veg', NULL, '400014001-P1S5I4', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001307, 400014001300, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001306, 400014001307, 90.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001020: PAV BHAJI (ONLY IN AMUL BUTTER)

-- Source: JSON, "pages[1].sections[6].columns[0].items[0]" -- Shubham Spl. Pav Bhaji | 235
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001301, 400014001, 400014001020, 10770, 'Shubham Spl. Pav Bhaji', 'shubham spl. pav bhaji', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60615 (new row in original script) -> existing 10770 'Special Pav Bhaji'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001308, 400014001301, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001307, 400014001308, 235.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[1]" -- Pav Bhaji | 175
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001302, 400014001, 400014001020, 10658, 'Pav Bhaji', 'pav bhaji', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001309, 400014001302, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001308, 400014001309, 175.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[2]" -- Cheese Pav Bhaji | 225
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001303, 400014001, 400014001020, 10161, 'Cheese Pav Bhaji', 'cheese pav bhaji', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001310, 400014001303, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001309, 400014001310, 225.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[3]" -- Jain Pav Bhaji | 180
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001304, 400014001, 400014001020, 10349, 'Jain Pav Bhaji', 'jain pav bhaji', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', TRUE, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001311, 400014001304, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001310, 400014001311, 180.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[4]" -- Jain Cheese Pav Bhaji | 225
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001305, 400014001, 400014001020, 10336, 'Jain Cheese Pav Bhaji', 'jain cheese pav bhaji', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', TRUE, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001312, 400014001305, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001311, 400014001312, 225.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[5]" -- Khada Handi Cheese Pav Bhaji | 240
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001306, 400014001, 400014001020, 10382, 'Khada Handi Cheese Pav Bhaji', 'khada handi cheese pav bhaji', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60616 (new row in original script) -> existing 10382 'Khada Cheese Pav Bhaji'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001313, 400014001306, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001312, 400014001313, 240.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[6]" -- Paneer Pav Bhaji | 225
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001307, 400014001, 400014001020, 10604, 'Paneer Pav Bhaji', 'paneer pav bhaji', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001314, 400014001307, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001313, 400014001314, 225.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[7]" -- Mushroom Pav Bhaji | 225
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001308, 400014001, 400014001020, 10484, 'Mushroom Pav Bhaji', 'mushroom pav bhaji', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001315, 400014001308, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001314, 400014001315, 225.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[8]" -- Masala Pav (2 Pcs) | 189
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001309, 400014001, 400014001020, 10426, 'Masala Pav (2 Pcs)', 'masala pav (2 pcs)', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001316, 400014001309, 'Regular', 'fixed', 2, 'pieces', 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001315, 400014001316, 189.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[9]" -- Cheese Masala Pav (2 Pcs) | 200
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001310, 400014001, 400014001020, 10140, 'Cheese Masala Pav (2 Pcs)', 'cheese masala pav (2 pcs)', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60617 (new row in original script) -> existing 10140 'Cheese Masala Pav'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001317, 400014001310, 'Regular', 'fixed', 2, 'pieces', 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001316, 400014001317, 200.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[10]" -- Pav Extra (2 Pcs) in Amul Butter | 50
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001311, 400014001, 400014001020, NULL, 'Pav Extra (2 Pcs) in Amul Butter', 'pav extra (2 pcs) in amul butter', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001318, 400014001311, 'Regular', 'fixed', 2, 'pieces', 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001317, 400014001318, 50.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[11]" -- Cheese Extra | 50
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001312, 400014001, 400014001020, NULL, 'Cheese Extra', 'cheese extra', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001319, 400014001312, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001318, 400014001319, 50.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[12]" -- Extra Butter | 40
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001313, 400014001, 400014001020, NULL, 'Extra Butter', 'extra butter', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001320, 400014001313, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001319, 400014001320, 40.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[13]" -- Only Bhaji | 150
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001314, 400014001, 400014001020, 13632, 'Only Bhaji', 'only bhaji', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001321, 400014001314, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001320, 400014001321, 150.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[14]" -- Sada Pav | 12
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001315, 400014001, 400014001020, 10727, 'Sada Pav', 'sada pav', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001322, 400014001315, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001321, 400014001322, 12.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[15]" -- Tawa Pulao | 245
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001316, 400014001, 400014001020, 13831, 'Tawa Pulao', 'tawa pulao', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001323, 400014001316, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001322, 400014001323, 245.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[16]" -- Cheese Tawa Pulao | 290
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001317, 400014001, 400014001020, 13154, 'Cheese Tawa Pulao', 'cheese tawa pulao', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001324, 400014001317, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001323, 400014001324, 290.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[17]" -- Paneer Tawa Pulao | 290
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001318, 400014001, 400014001020, 14198, 'Paneer Tawa Pulao', 'paneer tawa pulao', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001325, 400014001318, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001324, 400014001325, 290.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[6].columns[0].items[18]" -- Mushroom Tawa Pulao | 290
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001319, 400014001, 400014001020, 13606, 'Mushroom Tawa Pulao', 'mushroom tawa pulao', NULL, 'PAV BHAJI (ONLY IN AMUL BUTTER)', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60618 (new row in original script) -> existing 13606 'Mushroom Tawa Pulav'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001326, 400014001319, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001325, 400014001326, 290.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001021: PIZZA & BURGERS

-- Source: JSON, "pages[1].sections[7].columns[0].items[0]" -- Veg. Cheese Pizza | 240
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001320, 400014001, 400014001021, 10830, 'Veg. Cheese Pizza', 'veg. cheese pizza', NULL, 'PIZZA & BURGERS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60619 (new row in original script) -> existing 10830 'VEG CHEESE PIZZA'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001327, 400014001320, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001326, 400014001327, 240.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[7].columns[0].items[1]" -- Cheese Pizza | 275
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001321, 400014001, 400014001021, 10164, 'Cheese Pizza', 'cheese pizza', NULL, 'PIZZA & BURGERS', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001328, 400014001321, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001327, 400014001328, 275.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[7].columns[0].items[2]" -- Jain Pizza | 265
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001322, 400014001, 400014001021, 10350, 'Jain Pizza', 'jain pizza', NULL, 'PIZZA & BURGERS', 'veg', TRUE, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001329, 400014001322, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001328, 400014001329, 265.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[7].columns[0].items[3]" -- Palak Pizza | 265
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001323, 400014001, 400014001021, NULL, 'Palak Pizza', 'palak pizza', NULL, 'PIZZA & BURGERS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Palak Pizza' [was 60620]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001330, 400014001323, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001329, 400014001330, 265.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[7].columns[0].items[4]" -- Cheese Mushroom Pizza | 280
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001324, 400014001, 400014001021, 10473, 'Cheese Mushroom Pizza', 'cheese mushroom pizza', NULL, 'PIZZA & BURGERS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60621 (new row in original script) -> existing 10473 'Mushroom Cheese Pizza'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001331, 400014001324, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001330, 400014001331, 280.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[7].columns[0].items[5]" -- Tandoor Paneer Pizza | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001325, 400014001, 400014001021, NULL, 'Tandoor Paneer Pizza', 'tandoor paneer pizza', NULL, 'PIZZA & BURGERS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Tandoor Paneer Pizza' [was 60622]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001332, 400014001325, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001331, 400014001332, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[7].columns[0].items[6]" -- Corn Mushroom Pizza | 290
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001326, 400014001, 400014001021, NULL, 'Corn Mushroom Pizza', 'corn mushroom pizza', NULL, 'PIZZA & BURGERS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Corn Mushroom Pizza' [was 60623]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001333, 400014001326, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001332, 400014001333, 290.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[7].columns[0].items[7]" -- Mushroom Onion Tomato Pizza | 290
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001327, 400014001, 400014001021, NULL, 'Mushroom Onion Tomato Pizza', 'mushroom onion tomato pizza', NULL, 'PIZZA & BURGERS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Mushroom Onion Tomato Pizza' [was 60624]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001334, 400014001327, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001333, 400014001334, 290.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[7].columns[0].items[8]" -- Schezwan Paneer Pizza | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001328, 400014001, 400014001021, NULL, 'Schezwan Paneer Pizza', 'schezwan paneer pizza', NULL, 'PIZZA & BURGERS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Schezwan Paneer Pizza' [was 60625]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001335, 400014001328, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001334, 400014001335, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[7].columns[0].items[9]" -- Veg. Supreme Pizza | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001329, 400014001, 400014001021, NULL, 'Veg. Supreme Pizza', 'veg. supreme pizza', NULL, 'PIZZA & BURGERS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Veg. Supreme Pizza' [was 60626]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001336, 400014001329, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001335, 400014001336, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[7].columns[0].items[10]" -- Washington Pizza | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001330, 400014001, 400014001021, NULL, 'Washington Pizza', 'washington pizza', NULL, 'PIZZA & BURGERS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Washington Pizza' [was 60627]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001337, 400014001330, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001336, 400014001337, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[7].columns[0].items[11]" -- Green Cheese Burger | 180
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001331, 400014001, 400014001021, NULL, 'Green Cheese Burger', 'green cheese burger', NULL, 'PIZZA & BURGERS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Green Cheese Burger' [was 60628]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001338, 400014001331, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001337, 400014001338, 180.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[7].columns[0].items[12]" -- Veg. Burger | 120
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001332, 400014001, 400014001021, 10827, 'Veg. Burger', 'veg. burger', NULL, 'PIZZA & BURGERS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60629 (new row in original script) -> existing 10827 'Veg Burger'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001339, 400014001332, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001338, 400014001339, 120.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001022: SANDWICHES

-- Source: JSON, "pages[1].sections[8].columns[0].items[0]" -- Veg. Club Sandwich | 190
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001333, 400014001, 400014001022, 10834, 'Veg. Club Sandwich', 'veg. club sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60630 (new row in original script) -> existing 10834 'Veg Club Sandwich'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001340, 400014001333, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001339, 400014001340, 190.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[1]" -- Veg. Grilled Sandwich | 165
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001334, 400014001, 400014001022, 10836, 'Veg. Grilled Sandwich', 'veg. grilled sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60631 (new row in original script) -> existing 10836 'Veg Grilled Sandwich'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001341, 400014001334, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001340, 400014001341, 165.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[2]" -- Veg. Cheese Grilled Sandwich | 199
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001335, 400014001, 400014001022, 10829, 'Veg. Cheese Grilled Sandwich', 'veg. cheese grilled sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60632 (new row in original script) -> existing 10829 'Veg Cheese Grilled Sandwich'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001342, 400014001335, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001341, 400014001342, 199.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[3]" -- Paneer Cheese Grilled Sandwich | 230
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001336, 400014001, 400014001022, NULL, 'Paneer Cheese Grilled Sandwich', 'paneer cheese grilled sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Paneer Cheese Grilled Sandwich' [was 60633]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001343, 400014001336, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001342, 400014001343, 230.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[4]" -- Veg. Jumbo Sandwich | 210
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001337, 400014001, 400014001022, NULL, 'Veg. Jumbo Sandwich', 'veg. jumbo sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Veg. Jumbo Sandwich' [was 60634]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001344, 400014001337, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001343, 400014001344, 210.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[5]" -- Veg. Cheese Jumbo | 260
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001338, 400014001, 400014001022, NULL, 'Veg. Cheese Jumbo', 'veg. cheese jumbo', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Veg. Cheese Jumbo' [was 60635]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001345, 400014001338, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001344, 400014001345, 260.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[6]" -- Cheese Grilled Sandwich | 250
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001339, 400014001, 400014001022, 10134, 'Cheese Grilled Sandwich', 'cheese grilled sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60636 (new row in original script) -> existing 10134 'Cheese Grill Sandwich'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001346, 400014001339, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001345, 400014001346, 250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[7]" -- Veg. Sandwich | 95
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001340, 400014001, 400014001022, 10886, 'Veg. Sandwich', 'veg. sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001347, 400014001340, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001346, 400014001347, 95.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[8]" -- Veg. Toast Sandwich | 105
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001341, 400014001, 400014001022, 10894, 'Veg. Toast Sandwich', 'veg. toast sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001348, 400014001341, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001347, 400014001348, 105.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[9]" -- Veg. Cheese Toast Sandwich | 145
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001342, 400014001, 400014001022, 10858, 'Veg. Cheese Toast Sandwich', 'veg. cheese toast sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001349, 400014001342, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001348, 400014001349, 145.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[10]" -- Cheese Sandwich | 140
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001343, 400014001, 400014001022, 10167, 'Cheese Sandwich', 'cheese sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001350, 400014001343, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001349, 400014001350, 140.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[11]" -- Cheese Toast Sandwich | 140
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001344, 400014001, 400014001022, 10171, 'Cheese Toast Sandwich', 'cheese toast sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001351, 400014001344, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001350, 400014001351, 140.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[12]" -- Tomato Omlet Sandwich | 130
-- REVIEW: name suggests egg ("Omlet") but restaurant is declared pure vegetarian (JSON pure_veg=true); classified veg - confirm it is the eggless tomato omelette
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001345, 400014001, 400014001022, 11020, 'Tomato Omlet Sandwich', 'tomato omlet sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001352, 400014001345, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001351, 400014001352, 130.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[13]" -- Toast Tomato Omlet Sandwich | 145
-- REVIEW: name suggests egg ("Omlet") but restaurant is declared pure vegetarian (JSON pure_veg=true); classified veg - confirm it is the eggless tomato omelette
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001346, 400014001, 400014001022, NULL, 'Toast Tomato Omlet Sandwich', 'toast tomato omlet sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'needs_review');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Toast Tomato Omlet Sandwich' [was 60637]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001353, 400014001346, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001352, 400014001353, 145.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[14]" -- Bread Butter Toast | 95
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001347, 400014001, 400014001022, 23127, 'Bread Butter Toast', 'bread butter toast', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60638 (new row in original script) -> existing 23127 'Toast Bread Butter'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001354, 400014001347, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001353, 400014001354, 95.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[15]" -- Jam Butter Toast | 95
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001348, 400014001, 400014001022, 13388, 'Jam Butter Toast', 'jam butter toast', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60639 (new row in original script) -> existing 13388 'Jam Toast Butter'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001355, 400014001348, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001354, 400014001355, 95.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[16]" -- Jam Toast | 85
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001349, 400014001, 400014001022, 13387, 'Jam Toast', 'jam toast', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001356, 400014001349, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001355, 400014001356, 85.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[17]" -- Bread Butter | 85
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001350, 400014001, 400014001022, 23008, 'Bread Butter', 'bread butter', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001357, 400014001350, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001356, 400014001357, 85.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[18]" -- Chatni Sandwich | 85
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001351, 400014001, 400014001022, 10110, 'Chatni Sandwich', 'chatni sandwich', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001358, 400014001351, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001357, 400014001358, 85.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[8].columns[0].items[19]" -- Veg. Cheese S/W | 135
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001352, 400014001, 400014001022, 10857, 'Veg. Cheese S/W', 'veg. cheese s/w', NULL, 'SANDWICHES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60640 (new row in original script) -> existing 10857 'Veg. Cheese Sandwich'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001359, 400014001352, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001358, 400014001359, 135.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001023: CHAT

-- Source: JSON, "pages[1].sections[9].columns[0].items[0]" -- Bhel Puri | 100
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001353, 400014001, 400014001023, NULL, 'Bhel Puri', 'bhel puri', NULL, 'CHAT', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Bhel Puri' [was 60641]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001360, 400014001353, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001359, 400014001360, 100.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[9].columns[0].items[1]" -- Sev Puri | 100
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001354, 400014001, 400014001023, 23101, 'Sev Puri', 'sev puri', NULL, 'CHAT', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001361, 400014001354, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001360, 400014001361, 100.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[9].columns[0].items[2]" -- Special Bhel Puri | 110
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001355, 400014001, 400014001023, NULL, 'Special Bhel Puri', 'special bhel puri', NULL, 'CHAT', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Special Bhel Puri' [was 60642]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001362, 400014001355, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001361, 400014001362, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[9].columns[0].items[3]" -- Sev Batata Puri | 105
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001356, 400014001, 400014001023, NULL, 'Sev Batata Puri', 'sev batata puri', NULL, 'CHAT', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Sev Batata Puri' [was 60643]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001363, 400014001356, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001362, 400014001363, 105.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[9].columns[0].items[4]" -- Dahi Batata Puri | 115
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001357, 400014001, 400014001023, 23044, 'Dahi Batata Puri', 'dahi batata puri', NULL, 'CHAT', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001364, 400014001357, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001363, 400014001364, 115.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[9].columns[0].items[5]" -- Alu Chat | 130
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001358, 400014001, 400014001023, 10019, 'Alu Chat', 'alu chat', NULL, 'CHAT', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60644 (new row in original script) -> existing 10019 'Aloo Chaat'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001365, 400014001358, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001364, 400014001365, 130.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[9].columns[0].items[6]" -- Chinese Bhel | 160
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001359, 400014001, 400014001023, 10196, 'Chinese Bhel', 'chinese bhel', NULL, 'CHAT', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001366, 400014001359, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001365, 400014001366, 160.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001024: CHINESE SOUP

-- Source: JSON, "pages[1].sections[10].columns[0].items[0]" -- Tomato Soup / Palak Soup | 110
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001360, 400014001, 400014001024, 13865, 'Tomato Soup', 'tomato soup', NULL, 'CHINESE SOUP', 'veg', NULL, '400014001-P1S10I0', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001367, 400014001360, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001366, 400014001367, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[10].columns[0].items[0]" -- Tomato Soup / Palak Soup | 110
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001361, 400014001, 400014001024, 13662, 'Palak Soup', 'palak soup', NULL, 'CHINESE SOUP', 'veg', NULL, '400014001-P1S10I0', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001368, 400014001361, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001367, 400014001368, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[10].columns[0].items[1]" -- Veg. Clear Soup | 110
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001362, 400014001, 400014001024, 13899, 'Veg. Clear Soup', 'veg. clear soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60645 (new row in original script) -> existing 13899 'Veg Clear Soup'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001369, 400014001362, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001368, 400014001369, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[10].columns[0].items[2]" -- Plain Sweet Corn Soup | 120
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001363, 400014001, 400014001024, 13694, 'Plain Sweet Corn Soup', 'plain sweet corn soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001370, 400014001363, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001369, 400014001370, 120.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[10].columns[0].items[3]" -- Hot & Sour Soup | 120
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001364, 400014001, 400014001024, 13371, 'Hot & Sour Soup', 'hot & sour soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001371, 400014001364, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001370, 400014001371, 120.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[10].columns[0].items[4]" -- Veg. Sweet Corn Soup | 120
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001365, 400014001, 400014001024, 60270, 'Veg. Sweet Corn Soup', 'veg. sweet corn soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001372, 400014001365, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001371, 400014001372, 120.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[10].columns[0].items[5]" -- Manchow Soup | 130
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001366, 400014001, 400014001024, 13495, 'Manchow Soup', 'manchow soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001373, 400014001366, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001372, 400014001373, 130.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[10].columns[0].items[6]" -- Veg. Noodle Soup | 120
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001367, 400014001, 400014001024, 60236, 'Veg. Noodle Soup', 'veg. noodle soup', NULL, 'CHINESE SOUP', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001374, 400014001367, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001373, 400014001374, 120.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001025: TO START WITH

-- Source: JSON, "pages[1].sections[11].columns[0].items[0]" -- Idli Chilly | 205
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001368, 400014001, 400014001025, 10325, 'Idli Chilly', 'idli chilly', NULL, 'TO START WITH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001375, 400014001368, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001374, 400014001375, 205.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[11].columns[0].items[1]" -- Veg. Spring Roll | 250
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001369, 400014001, 400014001025, 10890, 'Veg. Spring Roll', 'veg. spring roll', NULL, 'TO START WITH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001376, 400014001369, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001375, 400014001376, 250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[11].columns[0].items[2]" -- Noodle Spring Roll | 275
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001370, 400014001, 400014001025, NULL, 'Noodle Spring Roll', 'noodle spring roll', NULL, 'TO START WITH', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Noodle Spring Roll' [was 60646]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001377, 400014001370, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001376, 400014001377, 275.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[11].columns[0].items[3]" -- Paneer Mushroom Spring Roll | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001371, 400014001, 400014001025, 10599, 'Paneer Mushroom Spring Roll', 'paneer mushroom spring roll', NULL, 'TO START WITH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001378, 400014001371, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001377, 400014001378, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[11].columns[0].items[4]" -- Veg. Crispy | 290
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001372, 400014001, 400014001025, 10871, 'Veg. Crispy', 'veg. crispy', NULL, 'TO START WITH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001379, 400014001372, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001378, 400014001379, 290.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[11].columns[0].items[5]" -- Paneer Crispy | 310
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001373, 400014001, 400014001025, 10571, 'Paneer Crispy', 'paneer crispy', NULL, 'TO START WITH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001380, 400014001373, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001379, 400014001380, 310.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[11].columns[0].items[6]" -- Mushroom Crispy | 320
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001374, 400014001, 400014001025, 10478, 'Mushroom Crispy', 'mushroom crispy', NULL, 'TO START WITH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001381, 400014001374, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001380, 400014001381, 320.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[11].columns[0].items[7]" -- Babycorn Manchurian Dry | 320
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001375, 400014001, 400014001025, NULL, 'Babycorn Manchurian Dry', 'babycorn manchurian dry', NULL, 'TO START WITH', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Babycorn Manchurian Dry' [was 60647]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001382, 400014001375, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001381, 400014001382, 320.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[11].columns[0].items[8]" -- Gobi Manchurian Dry | 275
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001376, 400014001, 400014001025, NULL, 'Gobi Manchurian Dry', 'gobi manchurian dry', NULL, 'TO START WITH', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Gobi Manchurian Dry' [was 60648]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001383, 400014001376, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001382, 400014001383, 275.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[11].columns[0].items[9]" -- Mushroom Manchurian Dry | 299
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001377, 400014001, 400014001025, NULL, 'Mushroom Manchurian Dry', 'mushroom manchurian dry', NULL, 'TO START WITH', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Mushroom Manchurian Dry' [was 60649]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001384, 400014001377, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001383, 400014001384, 299.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[11].columns[0].items[10]" -- Veg. Manchurian Dry | 265
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001378, 400014001, 400014001025, 10881, 'Veg. Manchurian Dry', 'veg. manchurian dry', NULL, 'TO START WITH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001385, 400014001378, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001384, 400014001385, 265.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[11].columns[0].items[11]" -- Paneer Manchurian Dry | 320
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001379, 400014001, 400014001025, 10592, 'Paneer Manchurian Dry', 'paneer manchurian dry', NULL, 'TO START WITH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001386, 400014001379, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001385, 400014001386, 320.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[11].columns[0].items[12]" -- Paneer Chilly Dry | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001380, 400014001, 400014001025, 10567, 'Paneer Chilly Dry', 'paneer chilly dry', NULL, 'TO START WITH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001387, 400014001380, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001386, 400014001387, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001026: CHINESE RICE

-- Source: JSON, "pages[1].sections[12].columns[0].items[0]" -- Shubham Spl. Fried Rice with Gravy | 320
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001381, 400014001, 400014001026, NULL, 'Shubham Spl. Fried Rice with Gravy', 'shubham spl. fried rice with gravy', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Shubham Spl. Fried Rice with Gravy' [was 60650]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001388, 400014001381, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001387, 400014001388, 320.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[1]" -- Veg. Fried Rice | 220
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001382, 400014001, 400014001026, 60168, 'Veg. Fried Rice', 'veg. fried rice', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001389, 400014001382, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001388, 400014001389, 220.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[2]" -- Schezwan Fried Rice | 245
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001383, 400014001, 400014001026, 13744, 'Schezwan Fried Rice', 'schezwan fried rice', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001390, 400014001383, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001389, 400014001390, 245.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[3]" -- Singapore Fried Rice | 245
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001384, 400014001, 400014001026, 13763, 'Singapore Fried Rice', 'singapore fried rice', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001391, 400014001384, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001390, 400014001391, 245.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[4]" -- Hong Kong Fried Rice | 245
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001385, 400014001, 400014001026, 13365, 'Hong Kong Fried Rice', 'hong kong fried rice', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001392, 400014001385, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001391, 400014001392, 245.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[5]" -- Combination Rice | 245
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001386, 400014001, 400014001026, 13192, 'Combination Rice', 'combination rice', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001393, 400014001386, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001392, 400014001393, 245.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[6]" -- Dragon Fried Rice | 245
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001387, 400014001, 400014001026, 13275, 'Dragon Fried Rice', 'dragon fried rice', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60651 (new row in original script) -> existing 13275 'Dragon Rice'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001394, 400014001387, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001393, 400014001394, 245.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[7]" -- Mushroom / Paneer Fried Rice | 275
-- REVIEW: name expanded from shortened source line "Mushroom / Paneer Fried Rice"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001388, 400014001, 400014001026, 13577, 'Mushroom Fried Rice', 'mushroom fried rice', NULL, 'CHINESE RICE', 'veg', NULL, '400014001-P1S12I7', 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001395, 400014001388, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001394, 400014001395, 275.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[7]" -- Mushroom / Paneer Fried Rice | 275
-- REVIEW: name expanded from shortened source line "Mushroom / Paneer Fried Rice"
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001389, 400014001, 400014001026, 14069, 'Paneer Fried Rice', 'paneer fried rice', NULL, 'CHINESE RICE', 'veg', NULL, '400014001-P1S12I7', 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001396, 400014001389, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001395, 400014001396, 275.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[8]" -- Mixed Fried Rice | 245
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001390, 400014001, 400014001026, 13544, 'Mixed Fried Rice', 'mixed fried rice', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60652 (new row in original script) -> existing 13544 'MIX FRIED RICE'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001397, 400014001390, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001396, 400014001397, 245.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[9]" -- Triple Schezwan Fried Rice | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001391, 400014001, 400014001026, 13870, 'Triple Schezwan Fried Rice', 'triple schezwan fried rice', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001398, 400014001391, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001397, 400014001398, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[10]" -- Baby Corn Schezwan Fried Rice | 280
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001392, 400014001, 400014001026, NULL, 'Baby Corn Schezwan Fried Rice', 'baby corn schezwan fried rice', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Baby Corn Schezwan Fried Rice' [was 60653]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001399, 400014001392, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001398, 400014001399, 280.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[11]" -- Paneer Schezwan Fried Rice | 285
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001393, 400014001, 400014001026, 14181, 'Paneer Schezwan Fried Rice', 'paneer schezwan fried rice', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001400, 400014001393, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001399, 400014001400, 285.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[12]" -- Mushroom Schezwan Fried Rice | 285
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001394, 400014001, 400014001026, 13602, 'Mushroom Schezwan Fried Rice', 'mushroom schezwan fried rice', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001401, 400014001394, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001400, 400014001401, 285.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[13]" -- Cauliflower Schezwan Fried Rice | 255
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001395, 400014001, 400014001026, NULL, 'Cauliflower Schezwan Fried Rice', 'cauliflower schezwan fried rice', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Cauliflower Schezwan Fried Rice' [was 60654]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001402, 400014001395, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001401, 400014001402, 255.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[14]" -- Extra Schezwan | 45
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001396, 400014001, 400014001026, NULL, 'Extra Schezwan', 'extra schezwan', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001403, 400014001396, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001402, 400014001403, 45.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[12].columns[0].items[15]" -- Veg Manchurian F'd Rice with Gravy | 320
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001397, 400014001, 400014001026, 13502, 'Veg Manchurian F''d Rice with Gravy', 'veg manchurian f''d rice with gravy', NULL, 'CHINESE RICE', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60655 (new row in original script) -> existing 13502 'Manchurian Rice With Gravy (Veg)'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001404, 400014001397, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001403, 400014001404, 320.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001027: NOODLES

-- Source: JSON, "pages[1].sections[13].columns[0].items[0]" -- Veg. Hakka Noodles | 225
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001398, 400014001, 400014001027, 60179, 'Veg. Hakka Noodles', 'veg. hakka noodles', NULL, 'NOODLES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001405, 400014001398, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001404, 400014001405, 225.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[13].columns[0].items[1]" -- Veg. Manchow Noodles | 245
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001399, 400014001, 400014001027, NULL, 'Veg. Manchow Noodles', 'veg. manchow noodles', NULL, 'NOODLES', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Veg. Manchow Noodles' [was 60656]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001406, 400014001399, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001405, 400014001406, 245.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[13].columns[0].items[2]" -- Mix Veg. Fried Noodles | 250
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001400, 400014001, 400014001027, 60462, 'Mix Veg. Fried Noodles', 'mix veg. fried noodles', NULL, 'NOODLES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60657 (new row in original script) -> existing 60462 'Veg. Fried Noodles'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001407, 400014001400, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001406, 400014001407, 250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[13].columns[0].items[3]" -- Singapore Noodles | 250
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001401, 400014001, 400014001027, 13764, 'Singapore Noodles', 'singapore noodles', NULL, 'NOODLES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001408, 400014001401, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001407, 400014001408, 250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[13].columns[0].items[4]" -- Schezwan Noodles | 245
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001402, 400014001, 400014001027, 13746, 'Schezwan Noodles', 'schezwan noodles', NULL, 'NOODLES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001409, 400014001402, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001408, 400014001409, 245.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[13].columns[0].items[5]" -- Chilly Garlic Hakka Noodles | 250
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001403, 400014001, 400014001027, 13162, 'Chilly Garlic Hakka Noodles', 'chilly garlic hakka noodles', NULL, 'NOODLES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60658 (new row in original script) -> existing 13162 'Chilli Garlic Noodles'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001410, 400014001403, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001409, 400014001410, 250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[13].columns[0].items[6]" -- Veg. Chowmein Noodles | 260
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001404, 400014001, 400014001027, 60158, 'Veg. Chowmein Noodles', 'veg. chowmein noodles', NULL, 'NOODLES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001411, 400014001404, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001410, 400014001411, 260.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[13].columns[0].items[7]" -- Veg. Dragon Noodles | 250
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001405, 400014001, 400014001027, NULL, 'Veg. Dragon Noodles', 'veg. dragon noodles', NULL, 'NOODLES', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Veg. Dragon Noodles' [was 60659]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001412, 400014001405, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001411, 400014001412, 250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[13].columns[0].items[8]" -- Veg. American Chopsuey | 250
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001406, 400014001, 400014001027, 13971, 'Veg. American Chopsuey', 'veg. american chopsuey', NULL, 'NOODLES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001413, 400014001406, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001412, 400014001413, 250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[13].columns[0].items[9]" -- Veg. Chinese Chopsuey | 260
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001407, 400014001, 400014001027, 13897, 'Veg. Chinese Chopsuey', 'veg. chinese chopsuey', NULL, 'NOODLES', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60660 (new row in original script) -> existing 13897 'Veg Chinese Chop Suey'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001414, 400014001407, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001413, 400014001414, 260.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[13].columns[0].items[10]" -- Paneer Schezwan Noodles | 275
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001408, 400014001, 400014001027, NULL, 'Paneer Schezwan Noodles', 'paneer schezwan noodles', NULL, 'NOODLES', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Paneer Schezwan Noodles' [was 60661]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001415, 400014001408, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001414, 400014001415, 275.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[13].columns[0].items[11]" -- Mushroom Schezwan Noodles | 280
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001409, 400014001, 400014001027, NULL, 'Mushroom Schezwan Noodles', 'mushroom schezwan noodles', NULL, 'NOODLES', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Mushroom Schezwan Noodles' [was 60662]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001416, 400014001409, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001415, 400014001416, 280.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[13].columns[0].items[12]" -- Triple Schezwan Noodles | 330
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001410, 400014001, 400014001027, 13871, 'Triple Schezwan Noodles', 'triple schezwan noodles', NULL, 'NOODLES', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001417, 400014001410, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001416, 400014001417, 330.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001028: CHINESE GRAVY

-- Source: JSON, "pages[1].sections[14].columns[0].items[0]" -- Paneer Manchurian | 250
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001411, 400014001, 400014001028, 10591, 'Paneer Manchurian', 'paneer manchurian', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001418, 400014001411, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001417, 400014001418, 250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[1]" -- Mushroom Manchurian | 250
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001412, 400014001, 400014001028, 10481, 'Mushroom Manchurian', 'mushroom manchurian', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001419, 400014001412, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001418, 400014001419, 250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[2]" -- Cauliflower Manchurian | 260
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001413, 400014001, 400014001028, 10100, 'Cauliflower Manchurian', 'cauliflower manchurian', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001420, 400014001413, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001419, 400014001420, 260.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[3]" -- Veg. Manchurian | 250
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001414, 400014001, 400014001028, 10880, 'Veg. Manchurian', 'veg. manchurian', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001421, 400014001414, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001420, 400014001421, 250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[4]" -- Baby Corn Chilly / Paneer Chilly | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001415, 400014001, 400014001028, 10044, 'Baby Corn Chilly', 'baby corn chilly', NULL, 'CHINESE GRAVY', 'veg', NULL, '400014001-P1S14I4', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001422, 400014001415, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001421, 400014001422, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[4]" -- Baby Corn Chilly / Paneer Chilly | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001416, 400014001, 400014001028, 10563, 'Paneer Chilly', 'paneer chilly', NULL, 'CHINESE GRAVY', 'veg', NULL, '400014001-P1S14I4', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001423, 400014001416, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001422, 400014001423, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[5]" -- Paneer Chilly in Green Sauce | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001417, 400014001, 400014001028, NULL, 'Paneer Chilly in Green Sauce', 'paneer chilly in green sauce', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Paneer Chilly in Green Sauce' [was 60663]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001424, 400014001417, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001423, 400014001424, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[6]" -- Paneer Chilly in Red Sauce | 290
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001418, 400014001, 400014001028, NULL, 'Paneer Chilly in Red Sauce', 'paneer chilly in red sauce', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Paneer Chilly in Red Sauce' [was 60664]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001425, 400014001418, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001424, 400014001425, 290.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[7]" -- Veg. Ball Chilly | 290
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001419, 400014001, 400014001028, NULL, 'Veg. Ball Chilly', 'veg. ball chilly', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Veg. Ball Chilly' [was 60665]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001426, 400014001419, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001425, 400014001426, 290.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[8]" -- Veg. Ball Mushroom in Red Sauce | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001420, 400014001, 400014001028, NULL, 'Veg. Ball Mushroom in Red Sauce', 'veg. ball mushroom in red sauce', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Veg. Ball Mushroom in Red Sauce' [was 60666]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001427, 400014001420, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001426, 400014001427, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[9]" -- Diced Veg. with (M) in Green Sauce | 295
-- REVIEW: "(M)" is not explained in the JSON (assumed mushroom); name kept verbatim
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001421, 400014001, 400014001028, NULL, 'Diced Veg. with (M) in Green Sauce', 'diced veg. with (m) in green sauce', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'needs_review');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Diced Veg. with (M) in Green Sauce' [was 60667]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001428, 400014001421, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001427, 400014001428, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[10]" -- Fried Veg. in Garlic Sauce | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001422, 400014001, 400014001028, NULL, 'Fried Veg. in Garlic Sauce', 'fried veg. in garlic sauce', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Fried Veg. in Garlic Sauce' [was 60668]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001429, 400014001422, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001428, 400014001429, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[11]" -- Sweet & Sour Veg | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001423, 400014001, 400014001028, 60268, 'Sweet & Sour Veg', 'sweet & sour veg', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60669 (new row in original script) -> existing 60268 'Veg. Sweet & Sour'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001430, 400014001423, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001429, 400014001430, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[12]" -- Veg. 65 | 285
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001424, 400014001, 400014001028, 10849, 'Veg. 65', 'veg. 65', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001431, 400014001424, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001430, 400014001431, 285.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[13]" -- Paneer 65 | 295
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001425, 400014001, 400014001028, 10540, 'Paneer 65', 'paneer 65', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001432, 400014001425, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001431, 400014001432, 295.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[14]" -- Soya Bean Chilly | 280
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001426, 400014001, 400014001028, 10766, 'Soya Bean Chilly', 'soya bean chilly', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60670 (new row in original script) -> existing 10766 'Soyabean Chilly'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001433, 400014001426, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001432, 400014001433, 280.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[14].columns[0].items[15]" -- Soya Bean Manchurian | 280
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001427, 400014001, 400014001028, 10767, 'Soya Bean Manchurian', 'soya bean manchurian', NULL, 'CHINESE GRAVY', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60671 (new row in original script) -> existing 10767 'Soyabean Manchurian'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001434, 400014001427, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001433, 400014001434, 280.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001029: KHANE KE SAATH SAATH

-- Source: JSON, "pages[1].sections[15].columns[0].items[0]" -- Green Salad | 140
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001428, 400014001, 400014001029, 60061, 'Green Salad', 'green salad', NULL, 'KHANE KE SAATH SAATH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001435, 400014001428, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001434, 400014001435, 140.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[15].columns[0].items[1]" -- Boondi Raita | 140
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001429, 400014001, 400014001029, 60016, 'Boondi Raita', 'boondi raita', NULL, 'KHANE KE SAATH SAATH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001436, 400014001429, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001435, 400014001436, 140.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[15].columns[0].items[2]" -- Jain Salad | 140
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001430, 400014001, 400014001029, NULL, 'Jain Salad', 'jain salad', NULL, 'KHANE KE SAATH SAATH', 'veg', TRUE, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Jain Salad' [was 60672]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001437, 400014001430, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001436, 400014001437, 140.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[15].columns[0].items[3]" -- Veg. Raita / Pineapple Raita | 110 / 145
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001431, 400014001, 400014001029, 60244, 'Veg. Raita', 'veg. raita', NULL, 'KHANE KE SAATH SAATH', 'veg', NULL, '400014001-P1S15I3', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001438, 400014001431, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001437, 400014001438, 110.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[15].columns[0].items[3]" -- Veg. Raita / Pineapple Raita | 110 / 145
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001432, 400014001, 400014001029, 60114, 'Pineapple Raita', 'pineapple raita', NULL, 'KHANE KE SAATH SAATH', 'veg', NULL, '400014001-P1S15I3', 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001439, 400014001432, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001438, 400014001439, 145.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[15].columns[0].items[4]" -- Masala Raita | 140
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001433, 400014001, 400014001029, NULL, 'Masala Raita', 'masala raita', NULL, 'KHANE KE SAATH SAATH', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Masala Raita' [was 60673]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001440, 400014001433, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001439, 400014001440, 140.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[15].columns[0].items[5]" -- Plain Curd | 99
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001434, 400014001, 400014001029, 13688, 'Plain Curd', 'plain curd', NULL, 'KHANE KE SAATH SAATH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001441, 400014001434, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001440, 400014001441, 99.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[15].columns[0].items[6]" -- Masala Papad | 70
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001435, 400014001, 400014001029, 60095, 'Masala Papad', 'masala papad', NULL, 'KHANE KE SAATH SAATH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001442, 400014001435, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001441, 400014001442, 70.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[15].columns[0].items[7]" -- Roasted Papad | 50
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001436, 400014001, 400014001029, 60126, 'Roasted Papad', 'roasted papad', NULL, 'KHANE KE SAATH SAATH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001443, 400014001436, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001442, 400014001443, 50.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[15].columns[0].items[8]" -- Fry Papad | 55
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001437, 400014001, 400014001029, 60057, 'Fry Papad', 'fry papad', NULL, 'KHANE KE SAATH SAATH', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001444, 400014001437, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001443, 400014001444, 55.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001030: INDIAN STARTERS

-- Source: JSON, "pages[1].sections[16].columns[0].items[0]" -- Cheese Pakoda | 340
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001438, 400014001, 400014001030, 10154, 'Cheese Pakoda', 'cheese pakoda', NULL, 'INDIAN STARTERS', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001445, 400014001438, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001444, 400014001445, 340.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[16].columns[0].items[1]" -- Mix Pakoda | 190
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001439, 400014001, 400014001030, 10457, 'Mix Pakoda', 'mix pakoda', NULL, 'INDIAN STARTERS', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001446, 400014001439, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001445, 400014001446, 190.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[16].columns[0].items[2]" -- Paneer Pakoda | 325
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001440, 400014001, 400014001030, 10603, 'Paneer Pakoda', 'paneer pakoda', NULL, 'INDIAN STARTERS', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001447, 400014001440, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001446, 400014001447, 325.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[16].columns[0].items[3]" -- Onion Pakoda | 100
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001441, 400014001, 400014001030, 10510, 'Onion Pakoda', 'onion pakoda', NULL, 'INDIAN STARTERS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60674 (new row in original script) -> existing 10510 'Onion Bhajiya'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001448, 400014001441, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001447, 400014001448, 100.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[16].columns[0].items[4]" -- Paneer Tikka | 300
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001442, 400014001, 400014001030, 10631, 'Paneer Tikka', 'paneer tikka', NULL, 'INDIAN STARTERS', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001449, 400014001442, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001448, 400014001449, 300.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[16].columns[0].items[5]" -- Paneer Hara Kebab | 340
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001443, 400014001, 400014001030, NULL, 'Paneer Hara Kebab', 'paneer hara kebab', NULL, 'INDIAN STARTERS', 'veg', NULL, NULL, 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Paneer Hara Kebab' [was 60675]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001450, 400014001443, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001449, 400014001450, 340.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[16].columns[0].items[6]" -- Veg. Seekh Kebab | 340
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001444, 400014001, 400014001030, 10846, 'Veg. Seekh Kebab', 'veg. seekh kebab', NULL, 'INDIAN STARTERS', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 60676 (new row in original script) -> existing 10846 'Veg Seekh Kabab'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001451, 400014001444, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001450, 400014001451, 340.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[16].columns[0].items[7]" -- Gobi Tikka / Stuffed Aloo | 310
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001445, 400014001, 400014001030, NULL, 'Gobi Tikka', 'gobi tikka', NULL, 'INDIAN STARTERS', 'veg', NULL, '400014001-P1S16I7', 'unverified');  -- FLAG: new canonical_dish required (no equivalent in canonical_dish): 'Gobi Tikka' [was 60677]; canonical_dish_id left NULL
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001452, 400014001445, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001451, 400014001452, 310.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[16].columns[0].items[7]" -- Gobi Tikka / Stuffed Aloo | 310
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001446, 400014001, 400014001030, 13072, 'Stuffed Aloo', 'stuffed aloo', NULL, 'INDIAN STARTERS', 'veg', NULL, '400014001-P1S16I7', 'unverified');  -- canonical_dish_id: was 60678 (new row in original script) -> existing 13072 'Bharwan Aloo'
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001453, 400014001446, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001452, 400014001453, 310.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- ---- CATEGORY 400014001031: NEW LUCKY FAMILY PACK

-- Source: JSON, "pages[1].sections[18].columns[0].items[0]" -- Special Veg. / Non Veg. Family Pack | 1250
-- REVIEW: restaurant is declared pure vegetarian but this line says "Veg. / Non Veg."; one price (1250) printed for both; kept as ONE item with NULL food_classification_code instead of guessing; single price for a "Veg. / Non Veg." line; unclear whether it applies to one or both packs
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001447, 400014001, 400014001031, NULL, 'Special Veg. / Non Veg. Family Pack', 'special veg. / non veg. family pack', '(Gravy 2 / Naan 5 / Tandoor Roti 10 / Thums up 2 litre)', 'NEW LUCKY FAMILY PACK', NULL, NULL, NULL, 'needs_review');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001454, 400014001447, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001453, 400014001454, 1250.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'needs_review');

-- ---- CATEGORY 400014001032: SALADS & RAITA

-- Source: JSON, "pages[1].sections[19].columns[0].items[0]" -- Green Salad | 25
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001448, 400014001, 400014001032, 60061, 'Green Salad', 'green salad', NULL, 'SALADS & RAITA', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001455, 400014001448, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001454, 400014001455, 25.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[19].columns[0].items[1]" -- Veg. Raita | 20
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001449, 400014001, 400014001032, 60244, 'Veg. Raita', 'veg. raita', NULL, 'SALADS & RAITA', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001456, 400014001449, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001455, 400014001456, 20.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- Source: JSON, "pages[1].sections[19].columns[0].items[2]" -- Papad | 10
INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    description, raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code)
VALUES (400014001450, 400014001, 400014001032, 60107, 'Papad', 'papad', NULL, 'SALADS & RAITA', 'veg', NULL, NULL, 'unverified');
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default)
VALUES
    (400014001457, 400014001450, 'Regular', 'fixed', NULL, NULL, 1, TRUE);
INSERT INTO menu_item_price (price_id, variant_id, price_amount, tax_regime_code, tax_inclusion_code, effective_from, source_id, verification_status_code)
VALUES
    (400014001456, 400014001457, 10.00, 'GST', 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 400014001, 'unverified');

-- =====================================================================
-- PROVENANCE: menu_item_source (item existence/name certainty) and
-- menu_item_price_source (price certainty). No standalone id columns exist on these tables.
-- =====================================================================
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
VALUES
    (400014001001, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001002, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001003, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001004, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001005, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001006, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001007, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001008, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001009, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001010, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001011, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001012, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001013, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001014, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001015, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001016, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001017, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001018, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001019, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001020, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001021, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001022, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001023, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001024, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001025, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001026, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001027, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001028, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001029, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001030, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001031, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001032, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001033, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001034, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001035, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001036, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001037, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001038, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001039, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001040, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001041, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001042, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001043, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001044, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001045, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001046, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001047, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001048, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001049, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001050, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001051, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001052, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001053, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001054, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001055, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001056, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001057, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001058, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001059, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001060, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001061, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001062, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001063, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001064, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001065, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001066, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001067, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001068, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001069, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001070, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001071, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001072, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001073, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001074, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001075, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001076, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001077, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001078, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001079, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001080, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001081, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001082, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001083, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001084, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001085, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001086, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001087, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001088, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001089, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001090, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001091, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001092, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001093, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001094, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001095, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001096, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001097, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001098, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001099, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001100, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001101, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001102, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001103, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001104, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001105, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001106, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001107, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001108, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001109, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001110, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001111, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001112, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001113, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001114, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001115, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001116, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001117, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001118, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001119, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001120, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001121, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001122, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001123, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001124, 400014001, 4000140010001, 0.60000, 'needs_review'),
    (400014001125, 400014001, 4000140010001, 0.60000, 'needs_review'),
    (400014001126, 400014001, 4000140010001, 0.60000, 'needs_review'),
    (400014001127, 400014001, 4000140010001, 0.60000, 'needs_review'),
    (400014001128, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001129, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001130, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001131, 400014001, 4000140010001, 0.60000, 'needs_review'),
    (400014001132, 400014001, 4000140010001, 0.60000, 'needs_review'),
    (400014001133, 400014001, 4000140010001, 0.60000, 'needs_review'),
    (400014001134, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001135, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001136, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001137, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001138, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001139, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001140, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001141, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001142, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001143, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001144, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001145, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001146, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001147, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001148, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001149, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001150, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001151, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001152, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001153, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001154, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001155, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001156, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001157, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001158, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001159, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001160, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001161, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001162, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001163, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001164, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001165, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001166, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001167, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001168, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001169, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001170, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001171, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001172, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001173, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001174, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001175, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001176, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001177, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001178, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001179, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001180, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001181, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001182, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001183, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001184, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001185, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001186, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001187, 400014001, 4000140010001, 0.90000, 'needs_review'),
    (400014001188, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001189, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001190, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001191, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001192, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001193, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001194, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001195, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001196, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001197, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001198, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001199, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001200, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001201, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001202, 400014001, 4000140010001, 0.70000, 'needs_review'),
    (400014001203, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001204, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001205, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001206, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001207, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001208, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001209, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001210, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001211, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001212, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001213, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001214, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001215, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001216, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001217, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001218, 400014001, 4000140010001, 0.70000, 'needs_review'),
    (400014001219, 400014001, 4000140010001, 0.70000, 'needs_review'),
    (400014001220, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001221, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001222, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001223, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001224, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001225, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001226, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001227, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001228, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001229, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001230, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001231, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001232, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001233, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001234, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001235, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001236, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001237, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001238, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001239, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001240, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001241, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001242, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001243, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001244, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001245, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001246, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001247, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001248, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001249, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001250, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001251, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001252, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001253, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001254, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001255, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001256, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001257, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001258, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001259, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001260, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001261, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001262, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001263, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001264, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001265, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001266, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001267, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001268, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001269, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001270, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001271, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001272, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001273, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001274, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001275, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001276, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001277, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001278, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001279, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001280, 400014001, 4000140010001, 0.70000, 'needs_review'),
    (400014001281, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001282, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001283, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001284, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001285, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001286, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001287, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001288, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001289, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001290, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001291, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001292, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001293, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001294, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001295, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001296, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001297, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001298, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001299, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001300, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001301, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001302, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001303, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001304, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001305, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001306, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001307, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001308, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001309, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001310, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001311, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001312, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001313, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001314, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001315, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001316, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001317, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001318, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001319, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001320, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001321, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001322, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001323, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001324, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001325, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001326, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001327, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001328, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001329, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001330, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001331, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001332, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001333, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001334, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001335, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001336, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001337, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001338, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001339, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001340, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001341, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001342, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001343, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001344, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001345, 400014001, 4000140010001, 0.70000, 'needs_review'),
    (400014001346, 400014001, 4000140010001, 0.70000, 'needs_review'),
    (400014001347, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001348, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001349, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001350, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001351, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001352, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001353, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001354, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001355, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001356, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001357, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001358, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001359, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001360, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001361, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001362, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001363, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001364, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001365, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001366, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001367, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001368, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001369, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001370, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001371, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001372, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001373, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001374, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001375, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001376, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001377, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001378, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001379, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001380, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001381, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001382, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001383, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001384, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001385, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001386, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001387, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001388, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001389, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001390, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001391, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001392, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001393, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001394, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001395, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001396, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001397, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001398, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001399, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001400, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001401, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001402, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001403, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001404, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001405, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001406, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001407, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001408, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001409, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001410, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001411, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001412, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001413, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001414, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001415, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001416, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001417, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001418, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001419, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001420, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001421, 400014001, 4000140010001, 0.75000, 'needs_review'),
    (400014001422, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001423, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001424, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001425, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001426, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001427, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001428, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001429, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001430, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001431, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001432, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001433, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001434, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001435, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001436, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001437, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001438, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001439, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001440, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001441, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001442, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001443, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001444, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001445, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001446, 400014001, 4000140010001, 0.90000, 'unverified'),
    (400014001447, 400014001, 4000140010001, 0.50000, 'needs_review'),
    (400014001448, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001449, 400014001, 4000140010001, 0.95000, 'unverified'),
    (400014001450, 400014001, 4000140010001, 0.95000, 'unverified');

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
VALUES
    (400014001001, 400014001, 4000140010001, 0.95000),
    (400014001002, 400014001, 4000140010001, 0.95000),
    (400014001003, 400014001, 4000140010001, 0.95000),
    (400014001004, 400014001, 4000140010001, 0.95000),
    (400014001005, 400014001, 4000140010001, 0.95000),
    (400014001006, 400014001, 4000140010001, 0.90000),
    (400014001007, 400014001, 4000140010001, 0.90000),
    (400014001008, 400014001, 4000140010001, 0.95000),
    (400014001009, 400014001, 4000140010001, 0.95000),
    (400014001010, 400014001, 4000140010001, 0.90000),
    (400014001011, 400014001, 4000140010001, 0.90000),
    (400014001012, 400014001, 4000140010001, 0.90000),
    (400014001013, 400014001, 4000140010001, 0.90000),
    (400014001014, 400014001, 4000140010001, 0.95000),
    (400014001015, 400014001, 4000140010001, 0.95000),
    (400014001016, 400014001, 4000140010001, 0.95000),
    (400014001017, 400014001, 4000140010001, 0.90000),
    (400014001018, 400014001, 4000140010001, 0.90000),
    (400014001019, 400014001, 4000140010001, 0.95000),
    (400014001020, 400014001, 4000140010001, 0.95000),
    (400014001021, 400014001, 4000140010001, 0.95000),
    (400014001022, 400014001, 4000140010001, 0.95000),
    (400014001023, 400014001, 4000140010001, 0.95000),
    (400014001024, 400014001, 4000140010001, 0.95000),
    (400014001025, 400014001, 4000140010001, 0.95000),
    (400014001026, 400014001, 4000140010001, 0.95000),
    (400014001027, 400014001, 4000140010001, 0.90000),
    (400014001028, 400014001, 4000140010001, 0.90000),
    (400014001029, 400014001, 4000140010001, 0.95000),
    (400014001030, 400014001, 4000140010001, 0.90000),
    (400014001031, 400014001, 4000140010001, 0.90000),
    (400014001032, 400014001, 4000140010001, 0.95000),
    (400014001033, 400014001, 4000140010001, 0.95000),
    (400014001034, 400014001, 4000140010001, 0.95000),
    (400014001035, 400014001, 4000140010001, 0.90000),
    (400014001036, 400014001, 4000140010001, 0.90000),
    (400014001037, 400014001, 4000140010001, 0.95000),
    (400014001038, 400014001, 4000140010001, 0.95000),
    (400014001039, 400014001, 4000140010001, 0.90000),
    (400014001040, 400014001, 4000140010001, 0.90000),
    (400014001041, 400014001, 4000140010001, 0.90000),
    (400014001042, 400014001, 4000140010001, 0.90000),
    (400014001043, 400014001, 4000140010001, 0.95000),
    (400014001044, 400014001, 4000140010001, 0.95000),
    (400014001045, 400014001, 4000140010001, 0.95000),
    (400014001046, 400014001, 4000140010001, 0.95000),
    (400014001047, 400014001, 4000140010001, 0.95000),
    (400014001048, 400014001, 4000140010001, 0.90000),
    (400014001049, 400014001, 4000140010001, 0.90000),
    (400014001050, 400014001, 4000140010001, 0.90000),
    (400014001051, 400014001, 4000140010001, 0.90000),
    (400014001052, 400014001, 4000140010001, 0.95000),
    (400014001053, 400014001, 4000140010001, 0.95000),
    (400014001054, 400014001, 4000140010001, 0.95000),
    (400014001055, 400014001, 4000140010001, 0.95000),
    (400014001056, 400014001, 4000140010001, 0.95000),
    (400014001057, 400014001, 4000140010001, 0.95000),
    (400014001058, 400014001, 4000140010001, 0.95000),
    (400014001059, 400014001, 4000140010001, 0.95000),
    (400014001060, 400014001, 4000140010001, 0.95000),
    (400014001061, 400014001, 4000140010001, 0.90000),
    (400014001062, 400014001, 4000140010001, 0.90000),
    (400014001063, 400014001, 4000140010001, 0.90000),
    (400014001064, 400014001, 4000140010001, 0.90000),
    (400014001065, 400014001, 4000140010001, 0.90000),
    (400014001066, 400014001, 4000140010001, 0.90000),
    (400014001067, 400014001, 4000140010001, 0.95000),
    (400014001068, 400014001, 4000140010001, 0.95000),
    (400014001069, 400014001, 4000140010001, 0.95000),
    (400014001070, 400014001, 4000140010001, 0.95000),
    (400014001071, 400014001, 4000140010001, 0.95000),
    (400014001072, 400014001, 4000140010001, 0.95000),
    (400014001073, 400014001, 4000140010001, 0.95000),
    (400014001074, 400014001, 4000140010001, 0.90000),
    (400014001075, 400014001, 4000140010001, 0.90000),
    (400014001076, 400014001, 4000140010001, 0.90000),
    (400014001077, 400014001, 4000140010001, 0.90000),
    (400014001078, 400014001, 4000140010001, 0.95000),
    (400014001079, 400014001, 4000140010001, 0.95000),
    (400014001080, 400014001, 4000140010001, 0.95000),
    (400014001081, 400014001, 4000140010001, 0.95000),
    (400014001082, 400014001, 4000140010001, 0.90000),
    (400014001083, 400014001, 4000140010001, 0.90000),
    (400014001084, 400014001, 4000140010001, 0.95000),
    (400014001085, 400014001, 4000140010001, 0.95000),
    (400014001086, 400014001, 4000140010001, 0.90000),
    (400014001087, 400014001, 4000140010001, 0.90000),
    (400014001088, 400014001, 4000140010001, 0.95000),
    (400014001089, 400014001, 4000140010001, 0.95000),
    (400014001090, 400014001, 4000140010001, 0.95000),
    (400014001091, 400014001, 4000140010001, 0.95000),
    (400014001092, 400014001, 4000140010001, 0.95000),
    (400014001093, 400014001, 4000140010001, 0.95000),
    (400014001094, 400014001, 4000140010001, 0.90000),
    (400014001095, 400014001, 4000140010001, 0.90000),
    (400014001096, 400014001, 4000140010001, 0.95000),
    (400014001097, 400014001, 4000140010001, 0.95000),
    (400014001098, 400014001, 4000140010001, 0.95000),
    (400014001099, 400014001, 4000140010001, 0.95000),
    (400014001100, 400014001, 4000140010001, 0.95000),
    (400014001101, 400014001, 4000140010001, 0.95000),
    (400014001102, 400014001, 4000140010001, 0.95000),
    (400014001103, 400014001, 4000140010001, 0.95000),
    (400014001104, 400014001, 4000140010001, 0.95000),
    (400014001105, 400014001, 4000140010001, 0.95000),
    (400014001106, 400014001, 4000140010001, 0.95000),
    (400014001107, 400014001, 4000140010001, 0.70000),
    (400014001108, 400014001, 4000140010001, 0.70000),
    (400014001109, 400014001, 4000140010001, 0.90000),
    (400014001110, 400014001, 4000140010001, 0.90000),
    (400014001111, 400014001, 4000140010001, 0.90000),
    (400014001112, 400014001, 4000140010001, 0.90000),
    (400014001113, 400014001, 4000140010001, 0.95000),
    (400014001114, 400014001, 4000140010001, 0.95000),
    (400014001115, 400014001, 4000140010001, 0.95000),
    (400014001116, 400014001, 4000140010001, 0.95000),
    (400014001117, 400014001, 4000140010001, 0.90000),
    (400014001118, 400014001, 4000140010001, 0.90000),
    (400014001119, 400014001, 4000140010001, 0.95000),
    (400014001120, 400014001, 4000140010001, 0.95000),
    (400014001121, 400014001, 4000140010001, 0.95000),
    (400014001122, 400014001, 4000140010001, 0.95000),
    (400014001123, 400014001, 4000140010001, 0.95000),
    (400014001124, 400014001, 4000140010001, 0.60000),
    (400014001125, 400014001, 4000140010001, 0.60000),
    (400014001126, 400014001, 4000140010001, 0.60000),
    (400014001127, 400014001, 4000140010001, 0.60000),
    (400014001128, 400014001, 4000140010001, 0.60000),
    (400014001129, 400014001, 4000140010001, 0.60000),
    (400014001130, 400014001, 4000140010001, 0.60000),
    (400014001131, 400014001, 4000140010001, 0.60000),
    (400014001132, 400014001, 4000140010001, 0.95000),
    (400014001133, 400014001, 4000140010001, 0.95000),
    (400014001134, 400014001, 4000140010001, 0.95000),
    (400014001135, 400014001, 4000140010001, 0.60000),
    (400014001136, 400014001, 4000140010001, 0.60000),
    (400014001137, 400014001, 4000140010001, 0.60000),
    (400014001138, 400014001, 4000140010001, 0.60000),
    (400014001139, 400014001, 4000140010001, 0.60000),
    (400014001140, 400014001, 4000140010001, 0.60000),
    (400014001141, 400014001, 4000140010001, 0.90000),
    (400014001142, 400014001, 4000140010001, 0.90000),
    (400014001143, 400014001, 4000140010001, 0.90000),
    (400014001144, 400014001, 4000140010001, 0.95000),
    (400014001145, 400014001, 4000140010001, 0.90000),
    (400014001146, 400014001, 4000140010001, 0.90000),
    (400014001147, 400014001, 4000140010001, 0.90000),
    (400014001148, 400014001, 4000140010001, 0.90000),
    (400014001149, 400014001, 4000140010001, 0.90000),
    (400014001150, 400014001, 4000140010001, 0.95000),
    (400014001151, 400014001, 4000140010001, 0.95000),
    (400014001152, 400014001, 4000140010001, 0.95000),
    (400014001153, 400014001, 4000140010001, 0.90000),
    (400014001154, 400014001, 4000140010001, 0.90000),
    (400014001155, 400014001, 4000140010001, 0.95000),
    (400014001156, 400014001, 4000140010001, 0.95000),
    (400014001157, 400014001, 4000140010001, 0.95000),
    (400014001158, 400014001, 4000140010001, 0.95000),
    (400014001159, 400014001, 4000140010001, 0.95000),
    (400014001160, 400014001, 4000140010001, 0.95000),
    (400014001161, 400014001, 4000140010001, 0.95000),
    (400014001162, 400014001, 4000140010001, 0.90000),
    (400014001163, 400014001, 4000140010001, 0.90000),
    (400014001164, 400014001, 4000140010001, 0.90000),
    (400014001165, 400014001, 4000140010001, 0.90000),
    (400014001166, 400014001, 4000140010001, 0.95000),
    (400014001167, 400014001, 4000140010001, 0.95000),
    (400014001168, 400014001, 4000140010001, 0.95000),
    (400014001169, 400014001, 4000140010001, 0.95000),
    (400014001170, 400014001, 4000140010001, 0.95000),
    (400014001171, 400014001, 4000140010001, 0.95000),
    (400014001172, 400014001, 4000140010001, 0.95000),
    (400014001173, 400014001, 4000140010001, 0.95000),
    (400014001174, 400014001, 4000140010001, 0.95000),
    (400014001175, 400014001, 4000140010001, 0.95000),
    (400014001176, 400014001, 4000140010001, 0.95000),
    (400014001177, 400014001, 4000140010001, 0.95000),
    (400014001178, 400014001, 4000140010001, 0.95000),
    (400014001179, 400014001, 4000140010001, 0.95000),
    (400014001180, 400014001, 4000140010001, 0.95000),
    (400014001181, 400014001, 4000140010001, 0.95000),
    (400014001182, 400014001, 4000140010001, 0.95000),
    (400014001183, 400014001, 4000140010001, 0.95000),
    (400014001184, 400014001, 4000140010001, 0.95000),
    (400014001185, 400014001, 4000140010001, 0.95000),
    (400014001186, 400014001, 4000140010001, 0.95000),
    (400014001187, 400014001, 4000140010001, 0.95000),
    (400014001188, 400014001, 4000140010001, 0.95000),
    (400014001189, 400014001, 4000140010001, 0.95000),
    (400014001190, 400014001, 4000140010001, 0.95000),
    (400014001191, 400014001, 4000140010001, 0.95000),
    (400014001192, 400014001, 4000140010001, 0.90000),
    (400014001193, 400014001, 4000140010001, 0.90000),
    (400014001194, 400014001, 4000140010001, 0.95000),
    (400014001195, 400014001, 4000140010001, 0.95000),
    (400014001196, 400014001, 4000140010001, 0.95000),
    (400014001197, 400014001, 4000140010001, 0.95000),
    (400014001198, 400014001, 4000140010001, 0.95000),
    (400014001199, 400014001, 4000140010001, 0.95000),
    (400014001200, 400014001, 4000140010001, 0.95000),
    (400014001201, 400014001, 4000140010001, 0.95000),
    (400014001202, 400014001, 4000140010001, 0.95000),
    (400014001203, 400014001, 4000140010001, 0.90000),
    (400014001204, 400014001, 4000140010001, 0.90000),
    (400014001205, 400014001, 4000140010001, 0.90000),
    (400014001206, 400014001, 4000140010001, 0.90000),
    (400014001207, 400014001, 4000140010001, 0.95000),
    (400014001208, 400014001, 4000140010001, 0.95000),
    (400014001209, 400014001, 4000140010001, 0.90000),
    (400014001210, 400014001, 4000140010001, 0.90000),
    (400014001211, 400014001, 4000140010001, 0.95000),
    (400014001212, 400014001, 4000140010001, 0.95000),
    (400014001213, 400014001, 4000140010001, 0.95000),
    (400014001214, 400014001, 4000140010001, 0.90000),
    (400014001215, 400014001, 4000140010001, 0.90000),
    (400014001216, 400014001, 4000140010001, 0.95000),
    (400014001217, 400014001, 4000140010001, 0.95000),
    (400014001218, 400014001, 4000140010001, 0.90000),
    (400014001219, 400014001, 4000140010001, 0.90000),
    (400014001220, 400014001, 4000140010001, 0.95000),
    (400014001221, 400014001, 4000140010001, 0.95000),
    (400014001222, 400014001, 4000140010001, 0.90000),
    (400014001223, 400014001, 4000140010001, 0.90000),
    (400014001224, 400014001, 4000140010001, 0.90000),
    (400014001225, 400014001, 4000140010001, 0.90000),
    (400014001226, 400014001, 4000140010001, 0.95000),
    (400014001227, 400014001, 4000140010001, 0.95000),
    (400014001228, 400014001, 4000140010001, 0.90000),
    (400014001229, 400014001, 4000140010001, 0.90000),
    (400014001230, 400014001, 4000140010001, 0.95000),
    (400014001231, 400014001, 4000140010001, 0.95000),
    (400014001232, 400014001, 4000140010001, 0.95000),
    (400014001233, 400014001, 4000140010001, 0.95000),
    (400014001234, 400014001, 4000140010001, 0.95000),
    (400014001235, 400014001, 4000140010001, 0.95000),
    (400014001236, 400014001, 4000140010001, 0.95000),
    (400014001237, 400014001, 4000140010001, 0.95000),
    (400014001238, 400014001, 4000140010001, 0.95000),
    (400014001239, 400014001, 4000140010001, 0.95000),
    (400014001240, 400014001, 4000140010001, 0.95000),
    (400014001241, 400014001, 4000140010001, 0.95000),
    (400014001242, 400014001, 4000140010001, 0.95000),
    (400014001243, 400014001, 4000140010001, 0.95000),
    (400014001244, 400014001, 4000140010001, 0.95000),
    (400014001245, 400014001, 4000140010001, 0.95000),
    (400014001246, 400014001, 4000140010001, 0.95000),
    (400014001247, 400014001, 4000140010001, 0.95000),
    (400014001248, 400014001, 4000140010001, 0.95000),
    (400014001249, 400014001, 4000140010001, 0.95000),
    (400014001250, 400014001, 4000140010001, 0.95000),
    (400014001251, 400014001, 4000140010001, 0.95000),
    (400014001252, 400014001, 4000140010001, 0.70000),
    (400014001253, 400014001, 4000140010001, 0.90000),
    (400014001254, 400014001, 4000140010001, 0.90000),
    (400014001255, 400014001, 4000140010001, 0.95000),
    (400014001256, 400014001, 4000140010001, 0.95000),
    (400014001257, 400014001, 4000140010001, 0.95000),
    (400014001258, 400014001, 4000140010001, 0.95000),
    (400014001259, 400014001, 4000140010001, 0.95000),
    (400014001260, 400014001, 4000140010001, 0.95000),
    (400014001261, 400014001, 4000140010001, 0.95000),
    (400014001262, 400014001, 4000140010001, 0.90000),
    (400014001263, 400014001, 4000140010001, 0.90000),
    (400014001264, 400014001, 4000140010001, 0.90000),
    (400014001265, 400014001, 4000140010001, 0.90000),
    (400014001266, 400014001, 4000140010001, 0.95000),
    (400014001267, 400014001, 4000140010001, 0.70000),
    (400014001268, 400014001, 4000140010001, 0.95000),
    (400014001269, 400014001, 4000140010001, 0.95000),
    (400014001270, 400014001, 4000140010001, 0.95000),
    (400014001271, 400014001, 4000140010001, 0.95000),
    (400014001272, 400014001, 4000140010001, 0.95000),
    (400014001273, 400014001, 4000140010001, 0.95000),
    (400014001274, 400014001, 4000140010001, 0.95000),
    (400014001275, 400014001, 4000140010001, 0.95000),
    (400014001276, 400014001, 4000140010001, 0.95000),
    (400014001277, 400014001, 4000140010001, 0.95000),
    (400014001278, 400014001, 4000140010001, 0.95000),
    (400014001279, 400014001, 4000140010001, 0.95000),
    (400014001280, 400014001, 4000140010001, 0.95000),
    (400014001281, 400014001, 4000140010001, 0.95000),
    (400014001282, 400014001, 4000140010001, 0.95000),
    (400014001283, 400014001, 4000140010001, 0.95000),
    (400014001284, 400014001, 4000140010001, 0.95000),
    (400014001285, 400014001, 4000140010001, 0.95000),
    (400014001286, 400014001, 4000140010001, 0.95000),
    (400014001287, 400014001, 4000140010001, 0.95000),
    (400014001288, 400014001, 4000140010001, 0.95000),
    (400014001289, 400014001, 4000140010001, 0.95000),
    (400014001290, 400014001, 4000140010001, 0.95000),
    (400014001291, 400014001, 4000140010001, 0.95000),
    (400014001292, 400014001, 4000140010001, 0.95000),
    (400014001293, 400014001, 4000140010001, 0.95000),
    (400014001294, 400014001, 4000140010001, 0.95000),
    (400014001295, 400014001, 4000140010001, 0.95000),
    (400014001296, 400014001, 4000140010001, 0.95000),
    (400014001297, 400014001, 4000140010001, 0.95000),
    (400014001298, 400014001, 4000140010001, 0.95000),
    (400014001299, 400014001, 4000140010001, 0.95000),
    (400014001300, 400014001, 4000140010001, 0.95000),
    (400014001301, 400014001, 4000140010001, 0.95000),
    (400014001302, 400014001, 4000140010001, 0.95000),
    (400014001303, 400014001, 4000140010001, 0.95000),
    (400014001304, 400014001, 4000140010001, 0.95000),
    (400014001305, 400014001, 4000140010001, 0.90000),
    (400014001306, 400014001, 4000140010001, 0.90000),
    (400014001307, 400014001, 4000140010001, 0.95000),
    (400014001308, 400014001, 4000140010001, 0.95000),
    (400014001309, 400014001, 4000140010001, 0.95000),
    (400014001310, 400014001, 4000140010001, 0.95000),
    (400014001311, 400014001, 4000140010001, 0.95000),
    (400014001312, 400014001, 4000140010001, 0.95000),
    (400014001313, 400014001, 4000140010001, 0.95000),
    (400014001314, 400014001, 4000140010001, 0.95000),
    (400014001315, 400014001, 4000140010001, 0.95000),
    (400014001316, 400014001, 4000140010001, 0.95000),
    (400014001317, 400014001, 4000140010001, 0.95000),
    (400014001318, 400014001, 4000140010001, 0.95000),
    (400014001319, 400014001, 4000140010001, 0.95000),
    (400014001320, 400014001, 4000140010001, 0.95000),
    (400014001321, 400014001, 4000140010001, 0.95000),
    (400014001322, 400014001, 4000140010001, 0.95000),
    (400014001323, 400014001, 4000140010001, 0.95000),
    (400014001324, 400014001, 4000140010001, 0.95000),
    (400014001325, 400014001, 4000140010001, 0.95000),
    (400014001326, 400014001, 4000140010001, 0.95000),
    (400014001327, 400014001, 4000140010001, 0.95000),
    (400014001328, 400014001, 4000140010001, 0.95000),
    (400014001329, 400014001, 4000140010001, 0.95000),
    (400014001330, 400014001, 4000140010001, 0.95000),
    (400014001331, 400014001, 4000140010001, 0.95000),
    (400014001332, 400014001, 4000140010001, 0.95000),
    (400014001333, 400014001, 4000140010001, 0.95000),
    (400014001334, 400014001, 4000140010001, 0.95000),
    (400014001335, 400014001, 4000140010001, 0.95000),
    (400014001336, 400014001, 4000140010001, 0.95000),
    (400014001337, 400014001, 4000140010001, 0.95000),
    (400014001338, 400014001, 4000140010001, 0.95000),
    (400014001339, 400014001, 4000140010001, 0.95000),
    (400014001340, 400014001, 4000140010001, 0.95000),
    (400014001341, 400014001, 4000140010001, 0.95000),
    (400014001342, 400014001, 4000140010001, 0.95000),
    (400014001343, 400014001, 4000140010001, 0.95000),
    (400014001344, 400014001, 4000140010001, 0.95000),
    (400014001345, 400014001, 4000140010001, 0.95000),
    (400014001346, 400014001, 4000140010001, 0.95000),
    (400014001347, 400014001, 4000140010001, 0.95000),
    (400014001348, 400014001, 4000140010001, 0.95000),
    (400014001349, 400014001, 4000140010001, 0.95000),
    (400014001350, 400014001, 4000140010001, 0.95000),
    (400014001351, 400014001, 4000140010001, 0.95000),
    (400014001352, 400014001, 4000140010001, 0.95000),
    (400014001353, 400014001, 4000140010001, 0.95000),
    (400014001354, 400014001, 4000140010001, 0.95000),
    (400014001355, 400014001, 4000140010001, 0.95000),
    (400014001356, 400014001, 4000140010001, 0.95000),
    (400014001357, 400014001, 4000140010001, 0.95000),
    (400014001358, 400014001, 4000140010001, 0.95000),
    (400014001359, 400014001, 4000140010001, 0.95000),
    (400014001360, 400014001, 4000140010001, 0.95000),
    (400014001361, 400014001, 4000140010001, 0.95000),
    (400014001362, 400014001, 4000140010001, 0.95000),
    (400014001363, 400014001, 4000140010001, 0.95000),
    (400014001364, 400014001, 4000140010001, 0.95000),
    (400014001365, 400014001, 4000140010001, 0.95000),
    (400014001366, 400014001, 4000140010001, 0.90000),
    (400014001367, 400014001, 4000140010001, 0.90000),
    (400014001368, 400014001, 4000140010001, 0.95000),
    (400014001369, 400014001, 4000140010001, 0.95000),
    (400014001370, 400014001, 4000140010001, 0.95000),
    (400014001371, 400014001, 4000140010001, 0.95000),
    (400014001372, 400014001, 4000140010001, 0.95000),
    (400014001373, 400014001, 4000140010001, 0.95000),
    (400014001374, 400014001, 4000140010001, 0.95000),
    (400014001375, 400014001, 4000140010001, 0.95000),
    (400014001376, 400014001, 4000140010001, 0.95000),
    (400014001377, 400014001, 4000140010001, 0.95000),
    (400014001378, 400014001, 4000140010001, 0.95000),
    (400014001379, 400014001, 4000140010001, 0.95000),
    (400014001380, 400014001, 4000140010001, 0.95000),
    (400014001381, 400014001, 4000140010001, 0.95000),
    (400014001382, 400014001, 4000140010001, 0.95000),
    (400014001383, 400014001, 4000140010001, 0.95000),
    (400014001384, 400014001, 4000140010001, 0.95000),
    (400014001385, 400014001, 4000140010001, 0.95000),
    (400014001386, 400014001, 4000140010001, 0.95000),
    (400014001387, 400014001, 4000140010001, 0.95000),
    (400014001388, 400014001, 4000140010001, 0.95000),
    (400014001389, 400014001, 4000140010001, 0.95000),
    (400014001390, 400014001, 4000140010001, 0.95000),
    (400014001391, 400014001, 4000140010001, 0.95000),
    (400014001392, 400014001, 4000140010001, 0.95000),
    (400014001393, 400014001, 4000140010001, 0.95000),
    (400014001394, 400014001, 4000140010001, 0.90000),
    (400014001395, 400014001, 4000140010001, 0.90000),
    (400014001396, 400014001, 4000140010001, 0.95000),
    (400014001397, 400014001, 4000140010001, 0.95000),
    (400014001398, 400014001, 4000140010001, 0.95000),
    (400014001399, 400014001, 4000140010001, 0.95000),
    (400014001400, 400014001, 4000140010001, 0.95000),
    (400014001401, 400014001, 4000140010001, 0.95000),
    (400014001402, 400014001, 4000140010001, 0.95000),
    (400014001403, 400014001, 4000140010001, 0.95000),
    (400014001404, 400014001, 4000140010001, 0.95000),
    (400014001405, 400014001, 4000140010001, 0.95000),
    (400014001406, 400014001, 4000140010001, 0.95000),
    (400014001407, 400014001, 4000140010001, 0.95000),
    (400014001408, 400014001, 4000140010001, 0.95000),
    (400014001409, 400014001, 4000140010001, 0.95000),
    (400014001410, 400014001, 4000140010001, 0.95000),
    (400014001411, 400014001, 4000140010001, 0.95000),
    (400014001412, 400014001, 4000140010001, 0.95000),
    (400014001413, 400014001, 4000140010001, 0.95000),
    (400014001414, 400014001, 4000140010001, 0.95000),
    (400014001415, 400014001, 4000140010001, 0.95000),
    (400014001416, 400014001, 4000140010001, 0.95000),
    (400014001417, 400014001, 4000140010001, 0.95000),
    (400014001418, 400014001, 4000140010001, 0.95000),
    (400014001419, 400014001, 4000140010001, 0.95000),
    (400014001420, 400014001, 4000140010001, 0.95000),
    (400014001421, 400014001, 4000140010001, 0.90000),
    (400014001422, 400014001, 4000140010001, 0.90000),
    (400014001423, 400014001, 4000140010001, 0.95000),
    (400014001424, 400014001, 4000140010001, 0.95000),
    (400014001425, 400014001, 4000140010001, 0.95000),
    (400014001426, 400014001, 4000140010001, 0.95000),
    (400014001427, 400014001, 4000140010001, 0.95000),
    (400014001428, 400014001, 4000140010001, 0.95000),
    (400014001429, 400014001, 4000140010001, 0.95000),
    (400014001430, 400014001, 4000140010001, 0.95000),
    (400014001431, 400014001, 4000140010001, 0.95000),
    (400014001432, 400014001, 4000140010001, 0.95000),
    (400014001433, 400014001, 4000140010001, 0.95000),
    (400014001434, 400014001, 4000140010001, 0.95000),
    (400014001435, 400014001, 4000140010001, 0.95000),
    (400014001436, 400014001, 4000140010001, 0.95000),
    (400014001437, 400014001, 4000140010001, 0.90000),
    (400014001438, 400014001, 4000140010001, 0.90000),
    (400014001439, 400014001, 4000140010001, 0.95000),
    (400014001440, 400014001, 4000140010001, 0.95000),
    (400014001441, 400014001, 4000140010001, 0.95000),
    (400014001442, 400014001, 4000140010001, 0.95000),
    (400014001443, 400014001, 4000140010001, 0.95000),
    (400014001444, 400014001, 4000140010001, 0.95000),
    (400014001445, 400014001, 4000140010001, 0.95000),
    (400014001446, 400014001, 4000140010001, 0.95000),
    (400014001447, 400014001, 4000140010001, 0.95000),
    (400014001448, 400014001, 4000140010001, 0.95000),
    (400014001449, 400014001, 4000140010001, 0.95000),
    (400014001450, 400014001, 4000140010001, 0.95000),
    (400014001451, 400014001, 4000140010001, 0.90000),
    (400014001452, 400014001, 4000140010001, 0.90000),
    (400014001453, 400014001, 4000140010001, 0.60000),
    (400014001454, 400014001, 4000140010001, 0.95000),
    (400014001455, 400014001, 4000140010001, 0.95000),
    (400014001456, 400014001, 4000140010001, 0.95000);

-- ---------------------------------------------------------------------
-- BUNDLES (1:1 extension of a menu_item). Contents are NOT itemised in the JSON, so no
-- bundle_group / bundle_component rows. The family-pack contents line is kept as description.
-- ---------------------------------------------------------------------
INSERT INTO bundle (bundle_id, menu_item_id, bundle_type_code, is_customizable, description)
VALUES
    (4000140010001, 400014001099, 'thali', FALSE, NULL),
    (4000140010002, 400014001447, 'combo', FALSE, '(Gravy 2 / Naan 5 / Tandoor Roti 10 / Thums up 2 litre)');

-- ---------------------------------------------------------------------
-- ITEM AVAILABILITY  Source: JSON, "Tawa Idli (After 11)"
-- Available from 11:00 every day (day_of_week NULL), no end time given.
-- ("Upma / Sheera (Only Morning)" gives no hours, so no row - see needs-review block.)
-- ---------------------------------------------------------------------
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time, is_active)
VALUES
    (400014001001, 400014001202, NULL, '11:00', NULL, TRUE);

-- ---------------------------------------------------------------------
-- MENU BOARD ITEMS - every item on the single board, JSON source order, with its category
-- ---------------------------------------------------------------------
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
VALUES
    (400014001001, 400014001, 400014001001, 400014001001, 400014001001, 1),
    (400014001002, 400014001, 400014001001, 400014001002, 400014001001, 2),
    (400014001003, 400014001, 400014001001, 400014001003, 400014001001, 3),
    (400014001004, 400014001, 400014001001, 400014001004, 400014001001, 4),
    (400014001005, 400014001, 400014001001, 400014001005, 400014001001, 5),
    (400014001006, 400014001, 400014001001, 400014001006, 400014001001, 6),
    (400014001007, 400014001, 400014001001, 400014001007, 400014001001, 7),
    (400014001008, 400014001, 400014001001, 400014001008, 400014001001, 8),
    (400014001009, 400014001, 400014001001, 400014001009, 400014001001, 9),
    (400014001010, 400014001, 400014001001, 400014001010, 400014001001, 10),
    (400014001011, 400014001, 400014001001, 400014001011, 400014001001, 11),
    (400014001012, 400014001, 400014001001, 400014001012, 400014001001, 12),
    (400014001013, 400014001, 400014001001, 400014001013, 400014001001, 13),
    (400014001014, 400014001, 400014001001, 400014001014, 400014001001, 14),
    (400014001015, 400014001, 400014001001, 400014001015, 400014001001, 15),
    (400014001016, 400014001, 400014001001, 400014001016, 400014001001, 16),
    (400014001017, 400014001, 400014001001, 400014001017, 400014001001, 17),
    (400014001018, 400014001, 400014001001, 400014001018, 400014001001, 18),
    (400014001019, 400014001, 400014001001, 400014001019, 400014001001, 19),
    (400014001020, 400014001, 400014001001, 400014001020, 400014001001, 20),
    (400014001021, 400014001, 400014001001, 400014001021, 400014001001, 21),
    (400014001022, 400014001, 400014001001, 400014001022, 400014001001, 22),
    (400014001023, 400014001, 400014001001, 400014001023, 400014001001, 23),
    (400014001024, 400014001, 400014001001, 400014001024, 400014001001, 24),
    (400014001025, 400014001, 400014001001, 400014001025, 400014001001, 25),
    (400014001026, 400014001, 400014001001, 400014001026, 400014001001, 26),
    (400014001027, 400014001, 400014001001, 400014001027, 400014001001, 27),
    (400014001028, 400014001, 400014001001, 400014001028, 400014001001, 28),
    (400014001029, 400014001, 400014001001, 400014001029, 400014001001, 29),
    (400014001030, 400014001, 400014001001, 400014001030, 400014001001, 30),
    (400014001031, 400014001, 400014001001, 400014001031, 400014001001, 31),
    (400014001032, 400014001, 400014001001, 400014001032, 400014001001, 32),
    (400014001033, 400014001, 400014001001, 400014001033, 400014001001, 33),
    (400014001034, 400014001, 400014001001, 400014001034, 400014001001, 34),
    (400014001035, 400014001, 400014001001, 400014001035, 400014001002, 35),
    (400014001036, 400014001, 400014001001, 400014001036, 400014001002, 36),
    (400014001037, 400014001, 400014001001, 400014001037, 400014001002, 37),
    (400014001038, 400014001, 400014001001, 400014001038, 400014001002, 38),
    (400014001039, 400014001, 400014001001, 400014001039, 400014001002, 39),
    (400014001040, 400014001, 400014001001, 400014001040, 400014001002, 40),
    (400014001041, 400014001, 400014001001, 400014001041, 400014001002, 41),
    (400014001042, 400014001, 400014001001, 400014001042, 400014001002, 42),
    (400014001043, 400014001, 400014001001, 400014001043, 400014001002, 43),
    (400014001044, 400014001, 400014001001, 400014001044, 400014001002, 44),
    (400014001045, 400014001, 400014001001, 400014001045, 400014001002, 45),
    (400014001046, 400014001, 400014001001, 400014001046, 400014001002, 46),
    (400014001047, 400014001, 400014001001, 400014001047, 400014001002, 47),
    (400014001048, 400014001, 400014001001, 400014001048, 400014001002, 48),
    (400014001049, 400014001, 400014001001, 400014001049, 400014001002, 49),
    (400014001050, 400014001, 400014001001, 400014001050, 400014001002, 50),
    (400014001051, 400014001, 400014001001, 400014001051, 400014001002, 51),
    (400014001052, 400014001, 400014001001, 400014001052, 400014001002, 52),
    (400014001053, 400014001, 400014001001, 400014001053, 400014001002, 53),
    (400014001054, 400014001, 400014001001, 400014001054, 400014001002, 54),
    (400014001055, 400014001, 400014001001, 400014001055, 400014001002, 55),
    (400014001056, 400014001, 400014001001, 400014001056, 400014001002, 56),
    (400014001057, 400014001, 400014001001, 400014001057, 400014001002, 57),
    (400014001058, 400014001, 400014001001, 400014001058, 400014001002, 58),
    (400014001059, 400014001, 400014001001, 400014001059, 400014001002, 59),
    (400014001060, 400014001, 400014001001, 400014001060, 400014001002, 60),
    (400014001061, 400014001, 400014001001, 400014001061, 400014001002, 61),
    (400014001062, 400014001, 400014001001, 400014001062, 400014001002, 62),
    (400014001063, 400014001, 400014001001, 400014001063, 400014001002, 63),
    (400014001064, 400014001, 400014001001, 400014001064, 400014001002, 64),
    (400014001065, 400014001, 400014001001, 400014001065, 400014001002, 65),
    (400014001066, 400014001, 400014001001, 400014001066, 400014001002, 66),
    (400014001067, 400014001, 400014001001, 400014001067, 400014001002, 67),
    (400014001068, 400014001, 400014001001, 400014001068, 400014001002, 68),
    (400014001069, 400014001, 400014001001, 400014001069, 400014001002, 69),
    (400014001070, 400014001, 400014001001, 400014001070, 400014001002, 70),
    (400014001071, 400014001, 400014001001, 400014001071, 400014001002, 71),
    (400014001072, 400014001, 400014001001, 400014001072, 400014001002, 72),
    (400014001073, 400014001, 400014001001, 400014001073, 400014001002, 73),
    (400014001074, 400014001, 400014001001, 400014001074, 400014001002, 74),
    (400014001075, 400014001, 400014001001, 400014001075, 400014001002, 75),
    (400014001076, 400014001, 400014001001, 400014001076, 400014001002, 76),
    (400014001077, 400014001, 400014001001, 400014001077, 400014001002, 77),
    (400014001078, 400014001, 400014001001, 400014001078, 400014001002, 78),
    (400014001079, 400014001, 400014001001, 400014001079, 400014001002, 79),
    (400014001080, 400014001, 400014001001, 400014001080, 400014001003, 80),
    (400014001081, 400014001, 400014001001, 400014001081, 400014001003, 81),
    (400014001082, 400014001, 400014001001, 400014001082, 400014001003, 82),
    (400014001083, 400014001, 400014001001, 400014001083, 400014001003, 83),
    (400014001084, 400014001, 400014001001, 400014001084, 400014001003, 84),
    (400014001085, 400014001, 400014001001, 400014001085, 400014001003, 85),
    (400014001086, 400014001, 400014001001, 400014001086, 400014001003, 86),
    (400014001087, 400014001, 400014001001, 400014001087, 400014001003, 87),
    (400014001088, 400014001, 400014001001, 400014001088, 400014001003, 88),
    (400014001089, 400014001, 400014001001, 400014001089, 400014001003, 89),
    (400014001090, 400014001, 400014001001, 400014001090, 400014001003, 90),
    (400014001091, 400014001, 400014001001, 400014001091, 400014001003, 91),
    (400014001092, 400014001, 400014001001, 400014001092, 400014001003, 92),
    (400014001093, 400014001, 400014001001, 400014001093, 400014001003, 93),
    (400014001094, 400014001, 400014001001, 400014001094, 400014001003, 94),
    (400014001095, 400014001, 400014001001, 400014001095, 400014001003, 95),
    (400014001096, 400014001, 400014001001, 400014001096, 400014001003, 96),
    (400014001097, 400014001, 400014001001, 400014001097, 400014001003, 97),
    (400014001098, 400014001, 400014001001, 400014001098, 400014001003, 98),
    (400014001099, 400014001, 400014001001, 400014001099, 400014001003, 99),
    (400014001100, 400014001, 400014001001, 400014001100, 400014001003, 100),
    (400014001101, 400014001, 400014001001, 400014001101, 400014001003, 101),
    (400014001102, 400014001, 400014001001, 400014001102, 400014001003, 102),
    (400014001103, 400014001, 400014001001, 400014001103, 400014001003, 103),
    (400014001104, 400014001, 400014001001, 400014001104, 400014001003, 104),
    (400014001105, 400014001, 400014001001, 400014001105, 400014001004, 105),
    (400014001106, 400014001, 400014001001, 400014001106, 400014001004, 106),
    (400014001107, 400014001, 400014001001, 400014001107, 400014001004, 107),
    (400014001108, 400014001, 400014001001, 400014001108, 400014001004, 108),
    (400014001109, 400014001, 400014001001, 400014001109, 400014001004, 109),
    (400014001110, 400014001, 400014001001, 400014001110, 400014001004, 110),
    (400014001111, 400014001, 400014001001, 400014001111, 400014001004, 111),
    (400014001112, 400014001, 400014001001, 400014001112, 400014001004, 112),
    (400014001113, 400014001, 400014001001, 400014001113, 400014001004, 113),
    (400014001114, 400014001, 400014001001, 400014001114, 400014001004, 114),
    (400014001115, 400014001, 400014001001, 400014001115, 400014001004, 115),
    (400014001116, 400014001, 400014001001, 400014001116, 400014001004, 116),
    (400014001117, 400014001, 400014001001, 400014001117, 400014001004, 117),
    (400014001118, 400014001, 400014001001, 400014001118, 400014001004, 118),
    (400014001119, 400014001, 400014001001, 400014001119, 400014001004, 119),
    (400014001120, 400014001, 400014001001, 400014001120, 400014001004, 120),
    (400014001121, 400014001, 400014001001, 400014001121, 400014001004, 121),
    (400014001122, 400014001, 400014001001, 400014001122, 400014001004, 122),
    (400014001123, 400014001, 400014001001, 400014001123, 400014001004, 123),
    (400014001124, 400014001, 400014001001, 400014001124, 400014001005, 124),
    (400014001125, 400014001, 400014001001, 400014001125, 400014001005, 125),
    (400014001126, 400014001, 400014001001, 400014001126, 400014001005, 126),
    (400014001127, 400014001, 400014001001, 400014001127, 400014001005, 127),
    (400014001128, 400014001, 400014001001, 400014001128, 400014001005, 128),
    (400014001129, 400014001, 400014001001, 400014001129, 400014001005, 129),
    (400014001130, 400014001, 400014001001, 400014001130, 400014001005, 130),
    (400014001131, 400014001, 400014001001, 400014001131, 400014001005, 131),
    (400014001132, 400014001, 400014001001, 400014001132, 400014001005, 132),
    (400014001133, 400014001, 400014001001, 400014001133, 400014001005, 133),
    (400014001134, 400014001, 400014001001, 400014001134, 400014001005, 134),
    (400014001135, 400014001, 400014001001, 400014001135, 400014001005, 135),
    (400014001136, 400014001, 400014001001, 400014001136, 400014001005, 136),
    (400014001137, 400014001, 400014001001, 400014001137, 400014001005, 137),
    (400014001138, 400014001, 400014001001, 400014001138, 400014001006, 138),
    (400014001139, 400014001, 400014001001, 400014001139, 400014001006, 139),
    (400014001140, 400014001, 400014001001, 400014001140, 400014001006, 140),
    (400014001141, 400014001, 400014001001, 400014001141, 400014001006, 141),
    (400014001142, 400014001, 400014001001, 400014001142, 400014001006, 142),
    (400014001143, 400014001, 400014001001, 400014001143, 400014001006, 143),
    (400014001144, 400014001, 400014001001, 400014001144, 400014001006, 144),
    (400014001145, 400014001, 400014001001, 400014001145, 400014001006, 145),
    (400014001146, 400014001, 400014001001, 400014001146, 400014001006, 146),
    (400014001147, 400014001, 400014001001, 400014001147, 400014001006, 147),
    (400014001148, 400014001, 400014001001, 400014001148, 400014001006, 148),
    (400014001149, 400014001, 400014001001, 400014001149, 400014001006, 149),
    (400014001150, 400014001, 400014001001, 400014001150, 400014001006, 150),
    (400014001151, 400014001, 400014001001, 400014001151, 400014001006, 151),
    (400014001152, 400014001, 400014001001, 400014001152, 400014001006, 152),
    (400014001153, 400014001, 400014001001, 400014001153, 400014001006, 153),
    (400014001154, 400014001, 400014001001, 400014001154, 400014001006, 154),
    (400014001155, 400014001, 400014001001, 400014001155, 400014001007, 155),
    (400014001156, 400014001, 400014001001, 400014001156, 400014001007, 156),
    (400014001157, 400014001, 400014001001, 400014001157, 400014001007, 157),
    (400014001158, 400014001, 400014001001, 400014001158, 400014001007, 158),
    (400014001159, 400014001, 400014001001, 400014001159, 400014001007, 159),
    (400014001160, 400014001, 400014001001, 400014001160, 400014001007, 160),
    (400014001161, 400014001, 400014001001, 400014001161, 400014001008, 161),
    (400014001162, 400014001, 400014001001, 400014001162, 400014001008, 162),
    (400014001163, 400014001, 400014001001, 400014001163, 400014001008, 163),
    (400014001164, 400014001, 400014001001, 400014001164, 400014001008, 164),
    (400014001165, 400014001, 400014001001, 400014001165, 400014001008, 165),
    (400014001166, 400014001, 400014001001, 400014001166, 400014001009, 166),
    (400014001167, 400014001, 400014001001, 400014001167, 400014001009, 167),
    (400014001168, 400014001, 400014001001, 400014001168, 400014001009, 168),
    (400014001169, 400014001, 400014001001, 400014001169, 400014001009, 169),
    (400014001170, 400014001, 400014001001, 400014001170, 400014001009, 170),
    (400014001171, 400014001, 400014001001, 400014001171, 400014001010, 171),
    (400014001172, 400014001, 400014001001, 400014001172, 400014001010, 172),
    (400014001173, 400014001, 400014001001, 400014001173, 400014001010, 173),
    (400014001174, 400014001, 400014001001, 400014001174, 400014001010, 174),
    (400014001175, 400014001, 400014001001, 400014001175, 400014001010, 175),
    (400014001176, 400014001, 400014001001, 400014001176, 400014001010, 176),
    (400014001177, 400014001, 400014001001, 400014001177, 400014001011, 177),
    (400014001178, 400014001, 400014001001, 400014001178, 400014001011, 178),
    (400014001179, 400014001, 400014001001, 400014001179, 400014001011, 179),
    (400014001180, 400014001, 400014001001, 400014001180, 400014001011, 180),
    (400014001181, 400014001, 400014001001, 400014001181, 400014001011, 181),
    (400014001182, 400014001, 400014001001, 400014001182, 400014001011, 182),
    (400014001183, 400014001, 400014001001, 400014001183, 400014001011, 183),
    (400014001184, 400014001, 400014001001, 400014001184, 400014001011, 184),
    (400014001185, 400014001, 400014001001, 400014001185, 400014001011, 185),
    (400014001186, 400014001, 400014001001, 400014001186, 400014001011, 186),
    (400014001187, 400014001, 400014001001, 400014001187, 400014001011, 187),
    (400014001188, 400014001, 400014001001, 400014001188, 400014001012, 188),
    (400014001189, 400014001, 400014001001, 400014001189, 400014001012, 189),
    (400014001190, 400014001, 400014001001, 400014001190, 400014001012, 190),
    (400014001191, 400014001, 400014001001, 400014001191, 400014001012, 191),
    (400014001192, 400014001, 400014001001, 400014001192, 400014001012, 192),
    (400014001193, 400014001, 400014001001, 400014001193, 400014001012, 193),
    (400014001194, 400014001, 400014001001, 400014001194, 400014001012, 194),
    (400014001195, 400014001, 400014001001, 400014001195, 400014001012, 195),
    (400014001196, 400014001, 400014001001, 400014001196, 400014001013, 196),
    (400014001197, 400014001, 400014001001, 400014001197, 400014001013, 197),
    (400014001198, 400014001, 400014001001, 400014001198, 400014001013, 198),
    (400014001199, 400014001, 400014001001, 400014001199, 400014001014, 199),
    (400014001200, 400014001, 400014001001, 400014001200, 400014001014, 200),
    (400014001201, 400014001, 400014001001, 400014001201, 400014001014, 201),
    (400014001202, 400014001, 400014001001, 400014001202, 400014001014, 202),
    (400014001203, 400014001, 400014001001, 400014001203, 400014001014, 203),
    (400014001204, 400014001, 400014001001, 400014001204, 400014001014, 204),
    (400014001205, 400014001, 400014001001, 400014001205, 400014001014, 205),
    (400014001206, 400014001, 400014001001, 400014001206, 400014001014, 206),
    (400014001207, 400014001, 400014001001, 400014001207, 400014001014, 207),
    (400014001208, 400014001, 400014001001, 400014001208, 400014001014, 208),
    (400014001209, 400014001, 400014001001, 400014001209, 400014001014, 209),
    (400014001210, 400014001, 400014001001, 400014001210, 400014001014, 210),
    (400014001211, 400014001, 400014001001, 400014001211, 400014001014, 211),
    (400014001212, 400014001, 400014001001, 400014001212, 400014001014, 212),
    (400014001213, 400014001, 400014001001, 400014001213, 400014001014, 213),
    (400014001214, 400014001, 400014001001, 400014001214, 400014001014, 214),
    (400014001215, 400014001, 400014001001, 400014001215, 400014001014, 215),
    (400014001216, 400014001, 400014001001, 400014001216, 400014001014, 216),
    (400014001217, 400014001, 400014001001, 400014001217, 400014001014, 217),
    (400014001218, 400014001, 400014001001, 400014001218, 400014001014, 218),
    (400014001219, 400014001, 400014001001, 400014001219, 400014001014, 219),
    (400014001220, 400014001, 400014001001, 400014001220, 400014001014, 220),
    (400014001221, 400014001, 400014001001, 400014001221, 400014001015, 221),
    (400014001222, 400014001, 400014001001, 400014001222, 400014001015, 222),
    (400014001223, 400014001, 400014001001, 400014001223, 400014001015, 223),
    (400014001224, 400014001, 400014001001, 400014001224, 400014001015, 224),
    (400014001225, 400014001, 400014001001, 400014001225, 400014001015, 225),
    (400014001226, 400014001, 400014001001, 400014001226, 400014001015, 226),
    (400014001227, 400014001, 400014001001, 400014001227, 400014001015, 227),
    (400014001228, 400014001, 400014001001, 400014001228, 400014001015, 228),
    (400014001229, 400014001, 400014001001, 400014001229, 400014001015, 229),
    (400014001230, 400014001, 400014001001, 400014001230, 400014001015, 230),
    (400014001231, 400014001, 400014001001, 400014001231, 400014001015, 231),
    (400014001232, 400014001, 400014001001, 400014001232, 400014001015, 232),
    (400014001233, 400014001, 400014001001, 400014001233, 400014001015, 233),
    (400014001234, 400014001, 400014001001, 400014001234, 400014001015, 234),
    (400014001235, 400014001, 400014001001, 400014001235, 400014001015, 235),
    (400014001236, 400014001, 400014001001, 400014001236, 400014001015, 236),
    (400014001237, 400014001, 400014001001, 400014001237, 400014001015, 237),
    (400014001238, 400014001, 400014001001, 400014001238, 400014001015, 238),
    (400014001239, 400014001, 400014001001, 400014001239, 400014001015, 239),
    (400014001240, 400014001, 400014001001, 400014001240, 400014001015, 240),
    (400014001241, 400014001, 400014001001, 400014001241, 400014001015, 241),
    (400014001242, 400014001, 400014001001, 400014001242, 400014001015, 242),
    (400014001243, 400014001, 400014001001, 400014001243, 400014001015, 243),
    (400014001244, 400014001, 400014001001, 400014001244, 400014001015, 244),
    (400014001245, 400014001, 400014001001, 400014001245, 400014001015, 245),
    (400014001246, 400014001, 400014001001, 400014001246, 400014001015, 246),
    (400014001247, 400014001, 400014001001, 400014001247, 400014001015, 247),
    (400014001248, 400014001, 400014001001, 400014001248, 400014001015, 248),
    (400014001249, 400014001, 400014001001, 400014001249, 400014001015, 249),
    (400014001250, 400014001, 400014001001, 400014001250, 400014001015, 250),
    (400014001251, 400014001, 400014001001, 400014001251, 400014001015, 251),
    (400014001252, 400014001, 400014001001, 400014001252, 400014001015, 252),
    (400014001253, 400014001, 400014001001, 400014001253, 400014001015, 253),
    (400014001254, 400014001, 400014001001, 400014001254, 400014001015, 254),
    (400014001255, 400014001, 400014001001, 400014001255, 400014001015, 255),
    (400014001256, 400014001, 400014001001, 400014001256, 400014001015, 256),
    (400014001257, 400014001, 400014001001, 400014001257, 400014001015, 257),
    (400014001258, 400014001, 400014001001, 400014001258, 400014001015, 258),
    (400014001259, 400014001, 400014001001, 400014001259, 400014001015, 259),
    (400014001260, 400014001, 400014001001, 400014001260, 400014001015, 260),
    (400014001261, 400014001, 400014001001, 400014001261, 400014001015, 261),
    (400014001262, 400014001, 400014001001, 400014001262, 400014001015, 262),
    (400014001263, 400014001, 400014001001, 400014001263, 400014001016, 263),
    (400014001264, 400014001, 400014001001, 400014001264, 400014001016, 264),
    (400014001265, 400014001, 400014001001, 400014001265, 400014001016, 265),
    (400014001266, 400014001, 400014001001, 400014001266, 400014001016, 266),
    (400014001267, 400014001, 400014001001, 400014001267, 400014001016, 267),
    (400014001268, 400014001, 400014001001, 400014001268, 400014001016, 268),
    (400014001269, 400014001, 400014001001, 400014001269, 400014001016, 269),
    (400014001270, 400014001, 400014001001, 400014001270, 400014001016, 270),
    (400014001271, 400014001, 400014001001, 400014001271, 400014001016, 271),
    (400014001272, 400014001, 400014001001, 400014001272, 400014001016, 272),
    (400014001273, 400014001, 400014001001, 400014001273, 400014001016, 273),
    (400014001274, 400014001, 400014001001, 400014001274, 400014001016, 274),
    (400014001275, 400014001, 400014001001, 400014001275, 400014001016, 275),
    (400014001276, 400014001, 400014001001, 400014001276, 400014001016, 276),
    (400014001277, 400014001, 400014001001, 400014001277, 400014001016, 277),
    (400014001278, 400014001, 400014001001, 400014001278, 400014001016, 278),
    (400014001279, 400014001, 400014001001, 400014001279, 400014001016, 279),
    (400014001280, 400014001, 400014001001, 400014001280, 400014001016, 280),
    (400014001281, 400014001, 400014001001, 400014001281, 400014001016, 281),
    (400014001282, 400014001, 400014001001, 400014001282, 400014001016, 282),
    (400014001283, 400014001, 400014001001, 400014001283, 400014001016, 283),
    (400014001284, 400014001, 400014001001, 400014001284, 400014001016, 284),
    (400014001285, 400014001, 400014001001, 400014001285, 400014001017, 285),
    (400014001286, 400014001, 400014001001, 400014001286, 400014001017, 286),
    (400014001287, 400014001, 400014001001, 400014001287, 400014001017, 287),
    (400014001288, 400014001, 400014001001, 400014001288, 400014001017, 288),
    (400014001289, 400014001, 400014001001, 400014001289, 400014001017, 289),
    (400014001290, 400014001, 400014001001, 400014001290, 400014001017, 290),
    (400014001291, 400014001, 400014001001, 400014001291, 400014001018, 291),
    (400014001292, 400014001, 400014001001, 400014001292, 400014001018, 292),
    (400014001293, 400014001, 400014001001, 400014001293, 400014001018, 293),
    (400014001294, 400014001, 400014001001, 400014001294, 400014001018, 294),
    (400014001295, 400014001, 400014001001, 400014001295, 400014001019, 295),
    (400014001296, 400014001, 400014001001, 400014001296, 400014001019, 296),
    (400014001297, 400014001, 400014001001, 400014001297, 400014001019, 297),
    (400014001298, 400014001, 400014001001, 400014001298, 400014001019, 298),
    (400014001299, 400014001, 400014001001, 400014001299, 400014001019, 299),
    (400014001300, 400014001, 400014001001, 400014001300, 400014001019, 300),
    (400014001301, 400014001, 400014001001, 400014001301, 400014001020, 301),
    (400014001302, 400014001, 400014001001, 400014001302, 400014001020, 302),
    (400014001303, 400014001, 400014001001, 400014001303, 400014001020, 303),
    (400014001304, 400014001, 400014001001, 400014001304, 400014001020, 304),
    (400014001305, 400014001, 400014001001, 400014001305, 400014001020, 305),
    (400014001306, 400014001, 400014001001, 400014001306, 400014001020, 306),
    (400014001307, 400014001, 400014001001, 400014001307, 400014001020, 307),
    (400014001308, 400014001, 400014001001, 400014001308, 400014001020, 308),
    (400014001309, 400014001, 400014001001, 400014001309, 400014001020, 309),
    (400014001310, 400014001, 400014001001, 400014001310, 400014001020, 310),
    (400014001311, 400014001, 400014001001, 400014001311, 400014001020, 311),
    (400014001312, 400014001, 400014001001, 400014001312, 400014001020, 312),
    (400014001313, 400014001, 400014001001, 400014001313, 400014001020, 313),
    (400014001314, 400014001, 400014001001, 400014001314, 400014001020, 314),
    (400014001315, 400014001, 400014001001, 400014001315, 400014001020, 315),
    (400014001316, 400014001, 400014001001, 400014001316, 400014001020, 316),
    (400014001317, 400014001, 400014001001, 400014001317, 400014001020, 317),
    (400014001318, 400014001, 400014001001, 400014001318, 400014001020, 318),
    (400014001319, 400014001, 400014001001, 400014001319, 400014001020, 319),
    (400014001320, 400014001, 400014001001, 400014001320, 400014001021, 320),
    (400014001321, 400014001, 400014001001, 400014001321, 400014001021, 321),
    (400014001322, 400014001, 400014001001, 400014001322, 400014001021, 322),
    (400014001323, 400014001, 400014001001, 400014001323, 400014001021, 323),
    (400014001324, 400014001, 400014001001, 400014001324, 400014001021, 324),
    (400014001325, 400014001, 400014001001, 400014001325, 400014001021, 325),
    (400014001326, 400014001, 400014001001, 400014001326, 400014001021, 326),
    (400014001327, 400014001, 400014001001, 400014001327, 400014001021, 327),
    (400014001328, 400014001, 400014001001, 400014001328, 400014001021, 328),
    (400014001329, 400014001, 400014001001, 400014001329, 400014001021, 329),
    (400014001330, 400014001, 400014001001, 400014001330, 400014001021, 330),
    (400014001331, 400014001, 400014001001, 400014001331, 400014001021, 331),
    (400014001332, 400014001, 400014001001, 400014001332, 400014001021, 332),
    (400014001333, 400014001, 400014001001, 400014001333, 400014001022, 333),
    (400014001334, 400014001, 400014001001, 400014001334, 400014001022, 334),
    (400014001335, 400014001, 400014001001, 400014001335, 400014001022, 335),
    (400014001336, 400014001, 400014001001, 400014001336, 400014001022, 336),
    (400014001337, 400014001, 400014001001, 400014001337, 400014001022, 337),
    (400014001338, 400014001, 400014001001, 400014001338, 400014001022, 338),
    (400014001339, 400014001, 400014001001, 400014001339, 400014001022, 339),
    (400014001340, 400014001, 400014001001, 400014001340, 400014001022, 340),
    (400014001341, 400014001, 400014001001, 400014001341, 400014001022, 341),
    (400014001342, 400014001, 400014001001, 400014001342, 400014001022, 342),
    (400014001343, 400014001, 400014001001, 400014001343, 400014001022, 343),
    (400014001344, 400014001, 400014001001, 400014001344, 400014001022, 344),
    (400014001345, 400014001, 400014001001, 400014001345, 400014001022, 345),
    (400014001346, 400014001, 400014001001, 400014001346, 400014001022, 346),
    (400014001347, 400014001, 400014001001, 400014001347, 400014001022, 347),
    (400014001348, 400014001, 400014001001, 400014001348, 400014001022, 348),
    (400014001349, 400014001, 400014001001, 400014001349, 400014001022, 349),
    (400014001350, 400014001, 400014001001, 400014001350, 400014001022, 350),
    (400014001351, 400014001, 400014001001, 400014001351, 400014001022, 351),
    (400014001352, 400014001, 400014001001, 400014001352, 400014001022, 352),
    (400014001353, 400014001, 400014001001, 400014001353, 400014001023, 353),
    (400014001354, 400014001, 400014001001, 400014001354, 400014001023, 354),
    (400014001355, 400014001, 400014001001, 400014001355, 400014001023, 355),
    (400014001356, 400014001, 400014001001, 400014001356, 400014001023, 356),
    (400014001357, 400014001, 400014001001, 400014001357, 400014001023, 357),
    (400014001358, 400014001, 400014001001, 400014001358, 400014001023, 358),
    (400014001359, 400014001, 400014001001, 400014001359, 400014001023, 359),
    (400014001360, 400014001, 400014001001, 400014001360, 400014001024, 360),
    (400014001361, 400014001, 400014001001, 400014001361, 400014001024, 361),
    (400014001362, 400014001, 400014001001, 400014001362, 400014001024, 362),
    (400014001363, 400014001, 400014001001, 400014001363, 400014001024, 363),
    (400014001364, 400014001, 400014001001, 400014001364, 400014001024, 364),
    (400014001365, 400014001, 400014001001, 400014001365, 400014001024, 365),
    (400014001366, 400014001, 400014001001, 400014001366, 400014001024, 366),
    (400014001367, 400014001, 400014001001, 400014001367, 400014001024, 367),
    (400014001368, 400014001, 400014001001, 400014001368, 400014001025, 368),
    (400014001369, 400014001, 400014001001, 400014001369, 400014001025, 369),
    (400014001370, 400014001, 400014001001, 400014001370, 400014001025, 370),
    (400014001371, 400014001, 400014001001, 400014001371, 400014001025, 371),
    (400014001372, 400014001, 400014001001, 400014001372, 400014001025, 372),
    (400014001373, 400014001, 400014001001, 400014001373, 400014001025, 373),
    (400014001374, 400014001, 400014001001, 400014001374, 400014001025, 374),
    (400014001375, 400014001, 400014001001, 400014001375, 400014001025, 375),
    (400014001376, 400014001, 400014001001, 400014001376, 400014001025, 376),
    (400014001377, 400014001, 400014001001, 400014001377, 400014001025, 377),
    (400014001378, 400014001, 400014001001, 400014001378, 400014001025, 378),
    (400014001379, 400014001, 400014001001, 400014001379, 400014001025, 379),
    (400014001380, 400014001, 400014001001, 400014001380, 400014001025, 380),
    (400014001381, 400014001, 400014001001, 400014001381, 400014001026, 381),
    (400014001382, 400014001, 400014001001, 400014001382, 400014001026, 382),
    (400014001383, 400014001, 400014001001, 400014001383, 400014001026, 383),
    (400014001384, 400014001, 400014001001, 400014001384, 400014001026, 384),
    (400014001385, 400014001, 400014001001, 400014001385, 400014001026, 385),
    (400014001386, 400014001, 400014001001, 400014001386, 400014001026, 386),
    (400014001387, 400014001, 400014001001, 400014001387, 400014001026, 387),
    (400014001388, 400014001, 400014001001, 400014001388, 400014001026, 388),
    (400014001389, 400014001, 400014001001, 400014001389, 400014001026, 389),
    (400014001390, 400014001, 400014001001, 400014001390, 400014001026, 390),
    (400014001391, 400014001, 400014001001, 400014001391, 400014001026, 391),
    (400014001392, 400014001, 400014001001, 400014001392, 400014001026, 392),
    (400014001393, 400014001, 400014001001, 400014001393, 400014001026, 393),
    (400014001394, 400014001, 400014001001, 400014001394, 400014001026, 394),
    (400014001395, 400014001, 400014001001, 400014001395, 400014001026, 395),
    (400014001396, 400014001, 400014001001, 400014001396, 400014001026, 396),
    (400014001397, 400014001, 400014001001, 400014001397, 400014001026, 397),
    (400014001398, 400014001, 400014001001, 400014001398, 400014001027, 398),
    (400014001399, 400014001, 400014001001, 400014001399, 400014001027, 399),
    (400014001400, 400014001, 400014001001, 400014001400, 400014001027, 400),
    (400014001401, 400014001, 400014001001, 400014001401, 400014001027, 401),
    (400014001402, 400014001, 400014001001, 400014001402, 400014001027, 402),
    (400014001403, 400014001, 400014001001, 400014001403, 400014001027, 403),
    (400014001404, 400014001, 400014001001, 400014001404, 400014001027, 404),
    (400014001405, 400014001, 400014001001, 400014001405, 400014001027, 405),
    (400014001406, 400014001, 400014001001, 400014001406, 400014001027, 406),
    (400014001407, 400014001, 400014001001, 400014001407, 400014001027, 407),
    (400014001408, 400014001, 400014001001, 400014001408, 400014001027, 408),
    (400014001409, 400014001, 400014001001, 400014001409, 400014001027, 409),
    (400014001410, 400014001, 400014001001, 400014001410, 400014001027, 410),
    (400014001411, 400014001, 400014001001, 400014001411, 400014001028, 411),
    (400014001412, 400014001, 400014001001, 400014001412, 400014001028, 412),
    (400014001413, 400014001, 400014001001, 400014001413, 400014001028, 413),
    (400014001414, 400014001, 400014001001, 400014001414, 400014001028, 414),
    (400014001415, 400014001, 400014001001, 400014001415, 400014001028, 415),
    (400014001416, 400014001, 400014001001, 400014001416, 400014001028, 416),
    (400014001417, 400014001, 400014001001, 400014001417, 400014001028, 417),
    (400014001418, 400014001, 400014001001, 400014001418, 400014001028, 418),
    (400014001419, 400014001, 400014001001, 400014001419, 400014001028, 419),
    (400014001420, 400014001, 400014001001, 400014001420, 400014001028, 420),
    (400014001421, 400014001, 400014001001, 400014001421, 400014001028, 421),
    (400014001422, 400014001, 400014001001, 400014001422, 400014001028, 422),
    (400014001423, 400014001, 400014001001, 400014001423, 400014001028, 423),
    (400014001424, 400014001, 400014001001, 400014001424, 400014001028, 424),
    (400014001425, 400014001, 400014001001, 400014001425, 400014001028, 425),
    (400014001426, 400014001, 400014001001, 400014001426, 400014001028, 426),
    (400014001427, 400014001, 400014001001, 400014001427, 400014001028, 427),
    (400014001428, 400014001, 400014001001, 400014001428, 400014001029, 428),
    (400014001429, 400014001, 400014001001, 400014001429, 400014001029, 429),
    (400014001430, 400014001, 400014001001, 400014001430, 400014001029, 430),
    (400014001431, 400014001, 400014001001, 400014001431, 400014001029, 431),
    (400014001432, 400014001, 400014001001, 400014001432, 400014001029, 432),
    (400014001433, 400014001, 400014001001, 400014001433, 400014001029, 433),
    (400014001434, 400014001, 400014001001, 400014001434, 400014001029, 434),
    (400014001435, 400014001, 400014001001, 400014001435, 400014001029, 435),
    (400014001436, 400014001, 400014001001, 400014001436, 400014001029, 436),
    (400014001437, 400014001, 400014001001, 400014001437, 400014001029, 437),
    (400014001438, 400014001, 400014001001, 400014001438, 400014001030, 438),
    (400014001439, 400014001, 400014001001, 400014001439, 400014001030, 439),
    (400014001440, 400014001, 400014001001, 400014001440, 400014001030, 440),
    (400014001441, 400014001, 400014001001, 400014001441, 400014001030, 441),
    (400014001442, 400014001, 400014001001, 400014001442, 400014001030, 442),
    (400014001443, 400014001, 400014001001, 400014001443, 400014001030, 443),
    (400014001444, 400014001, 400014001001, 400014001444, 400014001030, 444),
    (400014001445, 400014001, 400014001001, 400014001445, 400014001030, 445),
    (400014001446, 400014001, 400014001001, 400014001446, 400014001030, 446),
    (400014001447, 400014001, 400014001001, 400014001447, 400014001031, 447),
    (400014001448, 400014001, 400014001001, 400014001448, 400014001032, 448),
    (400014001449, 400014001, 400014001001, 400014001449, 400014001032, 449),
    (400014001450, 400014001, 400014001001, 400014001450, 400014001032, 450);

-- ---------------------------------------------------------------------
-- ADD-ONS
--   Dosa Extras  <- pages[1].sections[1].other_text: "Extra: Butter Rs 30/- extra",
--                   "Chutney / Sambhar Rs 12/-", "Cheese Rs 45/-", "Schezwan Rs 40/-"
--                   (printed under the DOSA'S section; linked to every dosa item;
--                    "Chutney / Sambhar" split into two options at the same price)
--   Milk Shake Extras <- category text "MILK SHAKES (WITH ICE CREAM 30/- EXTRA)";
--                   linked to every milk-shake item
-- ---------------------------------------------------------------------
INSERT INTO addon_group (addon_group_id, restaurant_id, name, selection_type, is_required)
VALUES (4000140010001, 400014001, 'Dosa Extras', 'multiple', FALSE),
       (4000140010002, 400014001, 'Milk Shake Extras', 'single', FALSE);

INSERT INTO addon_option (addon_option_id, addon_group_id, name, extra_price)
VALUES
    (4000140010001, 4000140010001, 'Butter', 30.00),
    (4000140010002, 4000140010001, 'Chutney', 12.00),
    (4000140010003, 4000140010001, 'Sambhar', 12.00),
    (4000140010004, 4000140010001, 'Cheese', 45.00),
    (4000140010005, 4000140010001, 'Schezwan', 40.00),
    (4000140010006, 4000140010002, 'Ice Cream', 30.00);

INSERT INTO menu_item_addon_group (menu_item_id, addon_group_id)
VALUES
    (400014001221, 4000140010001),
    (400014001222, 4000140010001),
    (400014001223, 4000140010001),
    (400014001224, 4000140010001),
    (400014001225, 4000140010001),
    (400014001226, 4000140010001),
    (400014001227, 4000140010001),
    (400014001228, 4000140010001),
    (400014001229, 4000140010001),
    (400014001230, 4000140010001),
    (400014001231, 4000140010001),
    (400014001232, 4000140010001),
    (400014001233, 4000140010001),
    (400014001234, 4000140010001),
    (400014001235, 4000140010001),
    (400014001236, 4000140010001),
    (400014001237, 4000140010001),
    (400014001238, 4000140010001),
    (400014001239, 4000140010001),
    (400014001240, 4000140010001),
    (400014001241, 4000140010001),
    (400014001242, 4000140010001),
    (400014001243, 4000140010001),
    (400014001244, 4000140010001),
    (400014001245, 4000140010001),
    (400014001246, 4000140010001),
    (400014001247, 4000140010001),
    (400014001248, 4000140010001),
    (400014001249, 4000140010001),
    (400014001250, 4000140010001),
    (400014001251, 4000140010001),
    (400014001252, 4000140010001),
    (400014001253, 4000140010001),
    (400014001254, 4000140010001),
    (400014001255, 4000140010001),
    (400014001256, 4000140010001),
    (400014001257, 4000140010001),
    (400014001258, 4000140010001),
    (400014001259, 4000140010001),
    (400014001260, 4000140010001),
    (400014001261, 4000140010001),
    (400014001262, 4000140010001),
    (400014001138, 4000140010002),
    (400014001139, 4000140010002),
    (400014001140, 4000140010002),
    (400014001141, 4000140010002),
    (400014001142, 4000140010002),
    (400014001143, 4000140010002),
    (400014001144, 4000140010002),
    (400014001145, 4000140010002),
    (400014001146, 4000140010002),
    (400014001147, 4000140010002),
    (400014001148, 4000140010002),
    (400014001149, 4000140010002),
    (400014001150, 4000140010002),
    (400014001151, 4000140010002),
    (400014001152, 4000140010002),
    (400014001153, 4000140010002),
    (400014001154, 4000140010002);

COMMIT;

-- =====================================================================
-- TRAILING BLOCK 1: rows with verification_status_code = needs_review or confidence < 0.8
-- =====================================================================
-- 400014001006 Tawa Mushroom Masala -> ITEM  conf 0.75: name expanded from shortened source line "Tawa Mushroom / Paneer Masala"
-- 400014001007 Tawa Paneer Masala -> ITEM  conf 0.75: name expanded from shortened source line "Tawa Mushroom / Paneer Masala"
-- 400014001061 Mushroom Handi -> ITEM  conf 0.75: name expanded from shortened source line "Mushroom Handi / Kadai"
-- 400014001062 Mushroom Kadai -> ITEM  conf 0.75: name expanded from shortened source line "Mushroom Handi / Kadai"
-- 400014001063 Mushroom Paneer Handi -> ITEM  conf 0.75: name expanded from shortened source line "Mushroom Paneer Handi / Kadai"
-- 400014001064 Mushroom Paneer Kadai -> ITEM  conf 0.75: name expanded from shortened source line "Mushroom Paneer Handi / Kadai"
-- 400014001065 Mushroom Babycorn Handi -> ITEM  conf 0.75: name expanded from shortened source line "Mushroom Babycorn Handi / Kadai"
-- 400014001066 Mushroom Babycorn Kadai -> ITEM  conf 0.75: name expanded from shortened source line "Mushroom Babycorn Handi / Kadai"
-- 400014001107 Butter Chapati -> ITEM  conf 0.75: name expanded from shortened source line "Butter Chapati / Roti"
-- 400014001107 Butter Chapati -> PRICE 400014001107 conf 0.70: 27/45 matched positionally to Butter Chapati/Butter Roti; Butter Roti dearer than Butter Chapati is unusual (plain Roti 12, Chapati 17)
-- 400014001108 Butter Roti -> ITEM  conf 0.75: name expanded from shortened source line "Butter Chapati / Roti"
-- 400014001108 Butter Roti -> PRICE 400014001108 conf 0.70: 27/45 matched positionally to Butter Chapati/Butter Roti; Butter Roti dearer than Butter Chapati is unusual (plain Roti 12, Chapati 17)
-- 400014001124 Apple / Plain -> ITEM  conf 0.60: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally
-- 400014001124 Apple / Plain -> PRICE 400014001124,400014001125 conf 0.60: positional label->price match is inferred
-- 400014001125 Mosambi / Plain -> ITEM  conf 0.60: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally
-- 400014001125 Mosambi / Plain -> PRICE 400014001126,400014001127 conf 0.60: positional label->price match is inferred
-- 400014001126 Orange / Plain -> ITEM  conf 0.60: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally
-- 400014001126 Orange / Plain -> PRICE 400014001128,400014001129 conf 0.60: positional label->price match is inferred
-- 400014001127 Ganga Jamuna / Plain -> ITEM  conf 0.60: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally
-- 400014001127 Ganga Jamuna / Plain -> PRICE 400014001130,400014001131 conf 0.60: positional label->price match is inferred
-- 400014001131 Pineapple Juice / Plain -> ITEM  conf 0.60: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally
-- 400014001131 Pineapple Juice / Plain -> PRICE 400014001135,400014001136 conf 0.60: positional label->price match is inferred
-- 400014001132 Watermelon / Plain -> ITEM  conf 0.60: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally
-- 400014001132 Watermelon / Plain -> PRICE 400014001137,400014001138 conf 0.60: positional label->price match is inferred
-- 400014001133 Mara Mari / Plain -> ITEM  conf 0.60: "X / Plain" with two prices: meaning of "Plain" not explained in JSON; variants named from the two labels, matched to prices positionally
-- 400014001133 Mara Mari / Plain -> PRICE 400014001139,400014001140 conf 0.60: positional label->price match is inferred
-- 400014001141 Mango (Seasonal) -> ITEM  conf 0.75: name expanded from shortened source line "Mango / Sitaphal (Seasonal)"
-- 400014001142 Sitaphal (Seasonal) -> ITEM  conf 0.75: name expanded from shortened source line "Mango / Sitaphal (Seasonal)"
-- 400014001187 Packaged Drinking Water -> ITEM  conf 0.90: two prices (13 / 26) but no size labels or legend; variant kept as raw text with NO price row rather than guessing which price is which
-- 400014001187 Packaged Drinking Water -> PRICE no price row conf 0.20: no price row created: 13 and 26 cannot be assigned to sizes without labels (raw text kept in variant_name)
-- 400014001202 Tawa Idli -> ITEM  conf 0.70: "(After 11)" read as available from 11:00 (a.m.) onwards, no end time; JSON does not say a.m./p.m.
-- 400014001218 Upma -> ITEM  conf 0.70: "(Only Morning)" applies to both Upma and Sheera but JSON gives no hours; kept as description, NO availability row created
-- 400014001219 Sheera -> ITEM  conf 0.70: "(Only Morning)" applies to both Upma and Sheera but JSON gives no hours; kept as description, NO availability row created
-- 400014001222 Sada Dosa Butter -> ITEM  conf 0.75: name expanded from shortened source line "Sada Dosa Butter / Cheese"
-- 400014001223 Sada Dosa Cheese -> ITEM  conf 0.75: name expanded from shortened source line "Sada Dosa Butter / Cheese"
-- 400014001246 Rawa Mysore Masala -> PRICE 400014001252 conf 0.70: price 250 is ~100 above its siblings (Rawa Mysore Sada 150; Butter/Cheese variants run +10..+25); possible misprint
-- 400014001261 Schezwan Cheese Sada Dosa -> PRICE 400014001267 conf 0.70: price 120 is below Schezwan Sada Dosa 155 although the cheese version normally costs more; possible misprint
-- 400014001280 Tomato Omlet -> ITEM  conf 0.70: name suggests egg ("Omlet") but restaurant is declared pure vegetarian (JSON pure_veg=true); classified veg - confirm it is the eggless tomato omelette
-- 400014001345 Tomato Omlet Sandwich -> ITEM  conf 0.70: name suggests egg ("Omlet") but restaurant is declared pure vegetarian (JSON pure_veg=true); classified veg - confirm it is the eggless tomato omelette
-- 400014001346 Toast Tomato Omlet Sandwich -> ITEM  conf 0.70: name suggests egg ("Omlet") but restaurant is declared pure vegetarian (JSON pure_veg=true); classified veg - confirm it is the eggless tomato omelette
-- 400014001388 Mushroom Fried Rice -> ITEM  conf 0.75: name expanded from shortened source line "Mushroom / Paneer Fried Rice"
-- 400014001389 Paneer Fried Rice -> ITEM  conf 0.75: name expanded from shortened source line "Mushroom / Paneer Fried Rice"
-- 400014001421 Diced Veg. with (M) in Green Sauce -> ITEM  conf 0.75: "(M)" is not explained in the JSON (assumed mushroom); name kept verbatim
-- 400014001447 Special Veg. / Non Veg. Family Pack -> ITEM  conf 0.50: restaurant is declared pure vegetarian but this line says "Veg. / Non Veg."; one price (1250) printed for both; kept as ONE item with NULL food_classification_code instead of guessing
-- 400014001447 Special Veg. / Non Veg. Family Pack -> PRICE 400014001453 conf 0.60: single price for a "Veg. / Non Veg." line; unclear whether it applies to one or both packs
-- Restaurant-level (needs review):
--   restaurant.veg_nonveg_status = 'pure_veg' from JSON restaurant.pure_veg = true and the name, but the
--     page 1 line "Special Veg. / Non Veg. Family Pack" mentions Non Veg. Confirm with the restaurant.
--   restaurant_delivery.self_delivery_available = TRUE is inferred (no partner named; own "HOME DELIVERY" text).
--   GST tax_inclusion_code = 'exclusive' is inferred from "GST APPLICABLE AS PER GOVT. RATES"; no rate given.
--   Elided-name expansions and 'X / Plain' juices: see item rows above.

-- =====================================================================
-- TRAILING BLOCK 2: restaurant-level information from the JSON with no schema home
-- =====================================================================
-- Tagline: "DADAR'S FAVOURITE MEET & EAT PLACE !!!" (restaurant.description left NULL)
-- price_per_person "Rs.200-400": no per-person column; cost_for_two_amount NOT derived/guessed
-- Page heading "TAKE AWAY MENU": prices loaded with service_mode_id NULL; dine-in not stated in JSON
-- Policy / charge statements printed on both pages (no amount, so not usable as menu_item_charge):
--     ORDER ONCE PLACED CANNOT BE CANCELLED
--     RATES ARE SUBJECT TO CHANGE WITHOUT PRIOR NOTICE
--     ALL FOOD IS PREPARED IN REFINED OIL
--     DISPOSABLES (EXTRA CARRY BAG / SPOON / PLATES / CONTAINER) WILL BE CHARGED EXTRA.
--     EXTRA CHARGES FOR OUT OF MENU ITEMS.
--     EXTRA TOPPINGS & ADDITIONS
--     RATES ON THE BILL WILL BE FINAL RATES.
--   ("HOME DELIVERY WILL TAKE 30 TO 45 MINUTES" -> kept in restaurant_service_mode.notes; no time column;
--    "GST APPLICABLE AS PER GOVT. RATES" -> applied as tax_regime_code GST / exclusive, rate NULL)
-- Empty heading pages[1].sections[17] "HOT / COLD BEVERAGES" (no items; category NOT created). Its lines:
--     ALL COLD DRINKS
--     ALL HOT DRINKS
--     SPECIAL LASSI / KESAR LASSI / MASALA MIX, 20/- EXTRA
--     SOFT TEA / COFFEE 45/30
--     HOT TEA / COFFEE 30/35
--   "SOFT TEA / COFFEE 45/30" and "HOT TEA / COFFEE 30/35" cannot be tied to items and conflict with the page-0
--   prices (Tea 39, Filter Coffee 58, Nescafe 63) - not loaded. "20/- EXTRA" has no stated base item.
-- Delivery radius / minimum order: not in JSON. No delivery partner named: no restaurant_delivery_provider row.
-- Restaurant email / website: empty in JSON (NULL).
-- Source images: 1000468483.jpg, 1000468482.jpg (no media_asset rows; JSON gives no storage URI)
-- Item-level Jain: is_jain = TRUE only for items whose printed name says Jain (Jain Pav Bhaji, Jain Cheese Pav Bhaji,
--   Jain Pizza, Jain Salad). "ALSO AVAILABLE IN JAIN" on the Shubham Veg. Special category is recorded as the
--   restaurant tag JAIN_AVAILABLE only (it does not say each dish is Jain).
-- change_event_outbox: not populated (payload shape not specified) - follow-up integration step.
-- Lookup values required but missing: none (PURE_VEG, JAIN_AVAILABLE, cuisine_chinese, cuisine_southindian,
--   service_mode takeaway / delivery all exist).
-- Schema note: menu_item.raw_category_text is documented in the schema as "NULL once menu_category_id is
--   curated", but the onboarding prompt asks for the verbatim category text to be kept; this script keeps it.
