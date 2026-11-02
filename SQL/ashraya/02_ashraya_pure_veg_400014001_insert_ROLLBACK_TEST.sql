
--\connect "KhaustanRestaurantMenu"
BEGIN;

-- ---------------------------------------------------------------------
-- PREFLIGHT: abort cleanly (nothing written) if already loaded or if a
-- read-only lookup row this script depends on is missing.
-- ---------------------------------------------------------------------
DO $$
DECLARE v_missing TEXT; v_n INT;
BEGIN
    IF EXISTS (SELECT 1 FROM establishment WHERE establishment_id = 401305001)
       OR EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = 401305001)
       OR EXISTS (SELECT 1 FROM source_record WHERE source_id = 401305001)
       OR EXISTS (SELECT 1 FROM menu_extraction_batch WHERE restaurant_id = 401305001) THEN
        RAISE EXCEPTION 'Establishment 401305001 is already loaded - aborting to avoid duplicate menu items.';
    END IF;

    SELECT string_agg(c, ', ') INTO v_missing
    FROM unnest(ARRAY['PURE_VEG', 'JAIN_AVAILABLE', 'cuisine_chinese', 'cuisine_punjabi', 'cuisine_southindian']) AS c
    WHERE NOT EXISTS (SELECT 1 FROM platform_tag t WHERE t.tag_code = c);
    IF v_missing IS NOT NULL THEN RAISE EXCEPTION 'platform_tag lookup rows missing: %', v_missing; END IF;

    IF NOT EXISTS (SELECT 1 FROM delivery_provider WHERE provider_code = 'SELF') THEN
        RAISE EXCEPTION 'delivery_provider lookup row SELF is missing';
    END IF;

    -- canonical_dish: 1) every EXISTING canonical_dish referenced by menu_item must exist with the expected
    -- normalized_name; 2) the 74 NEW canonical dishes created by this script must not exist yet
    -- (neither their ids nor their names) and 3) their canonical_dish_name ids must be free.
    SELECT count(*) INTO v_n
    FROM (VALUES
        (10044, 'baby corn chilly'),
        (10080, 'butter idli'),
        (10085, 'butter pav'),
        (10086, 'butter pav bhaji'),
        (10087, 'butter sada dosa'),
        (10140, 'cheese masala pav'),
        (10154, 'cheese pakoda'),
        (10161, 'cheese pav bhaji'),
        (10166, 'cheese sada dosa'),
        (10196, 'chinese bhel'),
        (10225, 'dahi idli'),
        (10228, 'dahi vada'),
        (10253, 'finger chips'),
        (10286, 'ghee podi idli'),
        (10310, 'hara bhara kabab'),
        (10321, 'idli'),
        (10325, 'idli chilly'),
        (10327, 'idli fry'),
        (10330, 'idli vada mix'),
        (10349, 'jain pav bhaji'),
        (10376, 'kanda bhajiya'),
        (10383, 'khada pav bhaji'),
        (10421, 'masala dosa'),
        (10424, 'masala pav'),
        (10432, 'masala uttappa'),
        (10445, 'medu vada'),
        (10456, 'misal pav'),
        (10457, 'mix pakoda'),
        (10469, 'mushroom babycorn chilli'),
        (10476, 'mushroom chilly'),
        (10481, 'mushroom manchurian'),
        (10489, 'mushroom tawa'),
        (10490, 'mushroom tikka'),
        (10493, 'mysore masala dosa'),
        (10500, 'mysore sada dosa'),
        (10515, 'onion masala dosa'),
        (10520, 'onion rava masala dosa'),
        (10522, 'onion rawa dosa'),
        (10525, 'onion sada dosa'),
        (10529, 'onion uttapa'),
        (10540, 'paneer 65'),
        (10545, 'paneer angara'),
        (10563, 'paneer chilly'),
        (10571, 'paneer crispy'),
        (10582, 'paneer kalimiri tikka'),
        (10589, 'paneer malai tikka'),
        (10591, 'paneer manchurian'),
        (10593, 'paneer masala dosa'),
        (10602, 'paneer pahadi tikka'),
        (10603, 'paneer pakoda'),
        (10609, 'paneer pudina tikka'),
        (10611, 'paneer sada dosa'),
        (10629, 'paneer tawa masala'),
        (10631, 'paneer tikka'),
        (10638, 'paneer tikka grilled sandwich'),
        (10647, 'panner masala uttapa'),
        (10655, 'paper masala dosa'),
        (10656, 'paper sada dosa'),
        (10658, 'pav bhaji'),
        (10682, 'plain uttapam'),
        (10690, 'potato vada'),
        (10705, 'rava masala dosa'),
        (10708, 'rava sada dosa'),
        (10721, 'sabudana vada'),
        (10726, 'sada dosa'),
        (10727, 'sada pav'),
        (10741, 'schezwan masala dosa'),
        (10747, 'schezwan sada dosa'),
        (10756, 'sev tomato masala'),
        (10766, 'soyabean chilly'),
        (10770, 'special pav bhaji'),
        (10783, 'sweet kachori'),
        (10809, 'tomato onion uttapa'),
        (10826, 'vada usal (potato)'),
        (10829, 'veg cheese grilled sandwich'),
        (10833, 'veg chilly'),
        (10836, 'veg grilled sandwich'),
        (10846, 'veg seekh kabab'),
        (10849, 'veg. 65'),
        (10857, 'veg. cheese sandwich'),
        (10866, 'veg. chilly milly'),
        (10871, 'veg. crispy'),
        (10872, 'veg. cutlet'),
        (10880, 'veg. manchurian'),
        (10886, 'veg. sandwich'),
        (11020, 'tomato omlet sandwich'),
        (13014, 'aloo gobi'),
        (13015, 'aloo methi'),
        (13017, 'aloo mutter'),
        (13019, 'aloo palak'),
        (13075, 'bhendi masala'),
        (13110, 'burnt garlic fried rice'),
        (13115, 'butter dal fry'),
        (13129, 'chana masala'),
        (13134, 'cheese butter masala'),
        (13154, 'cheese tawa pulao'),
        (13218, 'curd'),
        (13235, 'dal fry'),
        (13238, 'dal fry tadka'),
        (13242, 'dal khichdi'),
        (13243, 'dal khichdi tadka'),
        (13245, 'dal kolhapuri'),
        (13250, 'dal palak'),
        (13278, 'dum aloo punjabi'),
        (13366, 'hong kong noodles (veg)'),
        (13385, 'jain bhaji'),
        (13395, 'jeera rice'),
        (13409, 'kaju masala'),
        (13456, 'lasooni palak'),
        (13462, 'lemon coriander'),
        (13486, 'malai kofta'),
        (13526, 'methi mutter malai'),
        (13527, 'methi mutter masala'),
        (13552, 'mix veg'),
        (13570, 'mushroom biryani'),
        (13581, 'mushroom handi'),
        (13586, 'mushroom kadai'),
        (13588, 'mushroom makhanwala'),
        (13589, 'mushroom malvani'),
        (13592, 'mushroom masala'),
        (13598, 'mushroom palak'),
        (13603, 'mushroom soup'),
        (13608, 'mushroom tikka masala'),
        (13615, 'nargis kofta'),
        (13622, 'nescafe'),
        (13632, 'only bhaji'),
        (13653, 'palak khichdi'),
        (13662, 'palak soup'),
        (13692, 'plain palak'),
        (13717, 'red bull'),
        (13727, 'sabudana khichdi'),
        (13793, 'steam rice'),
        (13853, 'toast butter'),
        (13865, 'tomato soup'),
        (13879, 'upma'),
        (13899, 'veg clear soup'),
        (13903, 'veg diwani handi'),
        (13905, 'veg falguni'),
        (13914, 'veg jalfrazi'),
        (13919, 'veg kofta'),
        (13920, 'veg koliwada'),
        (13928, 'veg maharaja'),
        (13976, 'veg. bhuna masala'),
        (13977, 'veg. biryani'),
        (13988, 'veg. burnt garlic noodles'),
        (14010, 'kaju paneer masala'),
        (14034, 'paneer bhuna masala'),
        (14035, 'paneer bhurji'),
        (14038, 'paneer biryani'),
        (14044, 'paneer butter masala'),
        (14045, 'paneer chana'),
        (14069, 'paneer fried rice'),
        (14072, 'paneer handi'),
        (14078, 'paneer hong kong'),
        (14083, 'paneer hot garlic'),
        (14086, 'paneer hyderabadi'),
        (14096, 'paneer jalfrezi'),
        (14097, 'paneer kadai'),
        (14103, 'paneer khurchan'),
        (14106, 'paneer kolhapuri'),
        (14111, 'paneer korma'),
        (14114, 'paneer lababdar'),
        (14129, 'paneer makhanwala'),
        (14138, 'paneer masala'),
        (14151, 'paneer mutter'),
        (14156, 'paneer noodles'),
        (14163, 'paneer palak'),
        (14165, 'paneer paratha'),
        (14166, 'paneer pasanda'),
        (14168, 'paneer peshawari'),
        (14170, 'paneer pulao'),
        (14179, 'paneer schezwan'),
        (14181, 'paneer schezwan fried rice'),
        (14198, 'paneer tawa pulao'),
        (14202, 'paneer tikka biryani'),
        (14204, 'paneer tikka masala'),
        (14208, 'paneer triple schezwan fried rice'),
        (14217, 'spe. paneer cheese tawa pulao'),
        (23003, 'aloo paratha'),
        (23007, 'bhatura'),
        (23008, 'bread butter'),
        (23011, 'butter aloo paratha'),
        (23013, 'butter chapati'),
        (23014, 'butter cheese garlic naan'),
        (23016, 'butter garlic naan'),
        (23017, 'butter kulcha'),
        (23018, 'butter lachewala paratha'),
        (23020, 'butter naan'),
        (23024, 'butter roti'),
        (23025, 'butter stuffed paratha'),
        (23027, 'chapati'),
        (23041, 'chole bhatura'),
        (23051, 'garlic kulcha'),
        (23052, 'garlic naan'),
        (23061, 'kulcha'),
        (23066, 'lachcha paratha'),
        (23080, 'naan'),
        (23091, 'puri'),
        (23092, 'puri bhaji'),
        (23094, 'roti'),
        (23109, 'stuff paratha'),
        (30013, 'sizzling brownie'),
        (40005, 'butter scotch'),
        (40038, 'vanilla ice cream'),
        (50013, 'banana milk shake'),
        (50025, 'butter milk'),
        (50029, 'butter scotch falooda'),
        (50030, 'butter scotch shake'),
        (50034, 'chikku milk shake'),
        (50036, 'chocolate milk shake'),
        (50040, 'cold coffee'),
        (50042, 'cold coffee with ice-cream'),
        (50050, 'dry fruit falooda'),
        (50053, 'dry fruit milk shake'),
        (50057, 'filter coffee'),
        (50061, 'fresh lime soda'),
        (50062, 'fresh lime water'),
        (50081, 'kesar falooda'),
        (50091, 'lassi'),
        (50102, 'mango lassi'),
        (50104, 'mango milk shake'),
        (50109, 'milk'),
        (50110, 'mineral water'),
        (50133, 'royal falooda'),
        (50143, 'soft drinks'),
        (50147, 'strawberry falooda'),
        (50149, 'strawberry milk shake'),
        (50154, 'tea'),
        (50162, 'vanilla milk shake'),
        (51015, 'virgin mojito'),
        (60016, 'boondi raita'),
        (60042, 'fried papad'),
        (60061, 'green salad'),
        (60062, 'gulab jamun'),
        (60064, 'gulab jamun with vanilla ice cream'),
        (60076, 'khichiya masala papad'),
        (60078, 'khichiya roasted papad'),
        (60085, 'mango'),
        (60095, 'masala papad'),
        (60102, 'mosambi'),
        (60104, 'orange'),
        (60110, 'pineapple'),
        (60114, 'pineapple raita'),
        (60115, 'pineapple sheera'),
        (60126, 'roasted papad'),
        (60145, 'strawberry ice cream'),
        (60150, 'tomato salad'),
        (60159, 'veg. combination fried rice'),
        (60168, 'veg. fried rice'),
        (60179, 'veg. hakka noodles'),
        (60180, 'veg. handi'),
        (60185, 'veg. hong kong'),
        (60186, 'veg. hong kong fried rice'),
        (60191, 'veg. hot & sour soup'),
        (60192, 'veg. hot garlic'),
        (60194, 'veg. hyderabadi'),
        (60195, 'veg. hyderabadi biryani'),
        (60196, 'veg. jaipuri'),
        (60198, 'veg. kadai'),
        (60205, 'veg. kheema'),
        (60208, 'veg. kolhapuri'),
        (60210, 'veg. kurma'),
        (60213, 'veg. makhanwala'),
        (60217, 'veg. malwani'),
        (60228, 'veg. moglai'),
        (60240, 'veg. patiyala'),
        (60242, 'veg. pulao'),
        (60244, 'veg. raita'),
        (60248, 'veg. schezwan'),
        (60249, 'veg. schezwan fried rice'),
        (60251, 'veg. schezwan noodles'),
        (60260, 'veg. singapore fried rice'),
        (60261, 'veg. singapore noodles'),
        (60278, 'veg. tiranga'),
        (60283, 'veg. triple schezwan fried rice'),
        (60290, 'veg.tawa pulao'),
        (60331, 'watermelon'),
        (60378, 'choco chips'),
        (60411, 'mushroom pulao'),
        (60421, 'paneer malwani'),
        (60463, 'veg. tava masala')
    ) AS v(id, norm)
    JOIN canonical_dish d ON d.canonical_dish_id = v.id AND d.normalized_name = v.norm;
    IF v_n <> 281 THEN
        RAISE EXCEPTION 'Only % of 281 referenced existing canonical_dish (id, normalized_name) pairs match the database - canonical_dish has changed since this script was generated; regenerate this script', v_n;
    END IF;

    SELECT string_agg(i::text, ', ') INTO v_missing
    FROM unnest(ARRAY[
        10920, 10921, 10922, 10923, 10924, 10925, 10926, 10927, 10928, 10929,
        10930, 10931, 10932, 10933, 10934, 10935, 10936, 10937, 11021, 14224,
        14225, 14226, 14227, 14228, 14229, 14230, 14231, 23134, 40039, 40040,
        50164, 50165, 60466, 60467, 60468, 60469, 60470, 60471, 60472, 60473,
        60474, 60475, 60476, 60477, 60478, 60479, 60480, 60481, 60482, 60483,
        60484, 60485, 60486, 60487, 60488, 60489, 60490, 60491, 60492, 60493,
        60494, 60495, 60496, 60497, 60498, 60499, 60500, 60501, 60502, 60503,
        60504, 60505, 60506, 60507
    ]::bigint[]) AS i
    WHERE EXISTS (SELECT 1 FROM canonical_dish c WHERE c.canonical_dish_id = i);
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'New canonical_dish ids already exist (already created?): %', left(v_missing, 400);
    END IF;

    SELECT string_agg(n, ', ') INTO v_missing
    FROM unnest(ARRAY[
        'mangalore sada dosa', 'mangalore masala dosa', 'chilli garlic masala cheese dosa', 'onion papdi uttappa',
        'pizza uttappa', 'club grilled sandwich', 'mumbai double decker sandwich', 'veg mayo sandwich',
        'jain khada pav bhaji', 'special khada pav bhaji', 'special jain pav bhaji', 'jain masala pav',
        'cheese jain masala pav', 'saoji paneer tikka', 'gobi tikka', 'veg nepali chilly',
        'paneer mongolian', 'paneer nepali chilly', 'tomato omlet grilled sandwich', 'paneer lasooni palak',
        'paneer agri masala', 'paneer saoji masala', 'paneer chop', 'butter paneer paratha',
        'paneer schezwan noodles', 'paneer triple manchurian rice', 'paneer triple schezwan noodles', 'butter garlic kulcha',
        'cone ice cream', 'matka kulfi', 'jeera masala', 'rio',
        'zhinge masala fry', 'veg butter masala', 'veg lababdar', 'veg agri masala',
        'veg saoji masala', 'punjabi curry kofta', 'veg maratha tadka kofta', 'veg aashraya''s special',
        'mushroom kolhapuri', 'mushroom jalfrazie', 'mushroom butter masala', 'mushroom lababdar',
        'mushroom korma', 'mushroom hyderabadi', 'mushroom bhuna masala', 'mushroom agri masala',
        'mushroom saoji masala', 'mushroom khurchan', 'butter dal fry tadka', 'masoor dal fry',
        'masoor dal fry tadka', 'khichiya fried papad', 'palak khichdi tadka', 'khandeshi khichdi',
        'indrayani ghee rice', 'vathwadi masala bhat', 'phodnichi indrayani bhat', 'veg schezwan soup',
        'mushroom and palak soup', 'veg roast fried rice', 'veg combination schezwan fried rice', 'veg roast hakka noodle',
        'veg peking noodle', 'veg triple manchurian noodles', 'veg triple manchurian fried rice', 'veg triple nepali chilly',
        'veg triple chinese roast', 'veg triple peri peri', 'veg triple butter pepper', 'mushroom triple schezwan rice',
        'mushroom triple manchurian rice', 'mushroom triple schezwan noodles'
    ]::text[]) AS n
    WHERE EXISTS (SELECT 1 FROM canonical_dish c WHERE c.normalized_name = n);
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'A canonical_dish with this normalized_name already exists - reuse it instead of creating a duplicate: %', left(v_missing, 400);
    END IF;

    IF EXISTS (SELECT 1 FROM canonical_dish_name WHERE canonical_dish_name_id BETWEEN 4013050010001 AND 4013050010074) THEN
        RAISE EXCEPTION 'canonical_dish_name ids 4013050010001..4013050010074 are already in use';
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- Establishment + restaurant + source + extraction batch
-- Source: JSON, "restaurant"
-- city/locality parsed from the printed address (schema default for city is
-- 'Mumbai', which would be wrong for Virar); state not in JSON -> 'Maharashtra'.
-- email / website are empty strings in the JSON -> NULL.
-- ---------------------------------------------------------------------
INSERT INTO establishment (
    establishment_id, name, normalized_name, address_line1, address_line2,
    locality, city, state, country_code, postal_code, email_id, website_url,
    latitude, longitude
) VALUES (
    401305001,
    'ASHRAYA''S PURE VEG',
    lower(trim('ASHRAYA''S PURE VEG')),
    'Pandarinath Chaudhary Marg, Next to Amba Mata Temple, Bazar Ward',
    NULL,
    'Virar (East)',
    'Virar',
    'Maharashtra',
    'IN',
    '401305',
    NULL,
    NULL,
    19.0177649,
    72.8440939
);

INSERT INTO restaurant (
    restaurant_id, establishment_id, display_name, normalized_name,
    veg_nonveg_status, has_bar, bar_license_type, verification_status_code
) VALUES (
    401305001, 401305001, 'ASHRAYA''S PURE VEG', lower(trim('ASHRAYA''S PURE VEG')),
    'pure_veg',          -- JSON restaurant.pure_veg = true
    FALSE,               -- no bar data in JSON
    'none',              -- bar_license_type missing in JSON -> 'none'
    'needs_review'       -- address vs establishment_id / coordinates conflict (see header)
);

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (401305001, 'ai_menu_extraction', 'Ashraya_Pure_Veg_Menu_OCR.json');

INSERT INTO menu_extraction_batch (
    extraction_batch_id, restaurant_id, source_id, extractor_version,
    started_at, completed_at, status_code, overall_confidence
) VALUES (
    4013050010001, 401305001, 401305001, NULL,
    (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed', NULL
);

-- ---------------------------------------------------------------------
-- Phones  -- Source: JSON, "restaurant.phone" ("7378786789 / 8421786789"); same two
-- numbers repeat in pages[1] RESTAURANT INFORMATION. First-listed = primary.
-- restaurant_hours: intentionally NOT populated (conflicting hours; see trailing notes).
-- ---------------------------------------------------------------------
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary) VALUES
    (4013050010001, 401305001, '7378786789', TRUE),
    (4013050010002, 401305001, '8421786789', FALSE);

-- ---------------------------------------------------------------------
-- Restaurant tags (platform_tag rows are looked up by code, never created)
--   PURE_VEG        : JSON restaurant.pure_veg = true
--   JAIN_AVAILABLE  : INFERRED from six items whose printed names say "Jain"
--   cuisine_*       : INFERRED from section headers (CHINESE ..., (PUNJABI DISHES), SOUTH INDIAN SNACKS)
-- ---------------------------------------------------------------------
INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean) VALUES
    (4013050010001, 401305001, (SELECT tag_id FROM platform_tag WHERE tag_code = 'PURE_VEG'), TRUE),
    (4013050010002, 401305001, (SELECT tag_id FROM platform_tag WHERE tag_code = 'JAIN_AVAILABLE'), TRUE),
    (4013050010003, 401305001, (SELECT tag_id FROM platform_tag WHERE tag_code = 'cuisine_chinese'), TRUE),
    (4013050010004, 401305001, (SELECT tag_id FROM platform_tag WHERE tag_code = 'cuisine_punjabi'), TRUE),
    (4013050010005, 401305001, (SELECT tag_id FROM platform_tag WHERE tag_code = 'cuisine_southindian'), TRUE);

-- ---------------------------------------------------------------------
-- Delivery  -- Source: pages[1] RESTAURANT INFORMATION: "FREE HOME DELIVERY",
-- "MINIMUM ORDER RS. 200/-". No third-party partner is named, so this is loaded as
-- the restaurant's own delivery (existing lookup row SELF); free -> base charge 0.
-- No delivery radius in the JSON.
-- ---------------------------------------------------------------------
INSERT INTO restaurant_delivery (
    restaurant_id, delivery_available, self_delivery_available, self_delivery_min_order_amount, currency_code, status_code
) VALUES (401305001, TRUE, TRUE, 200.00, 'INR', 'active');

INSERT INTO restaurant_delivery_provider (
    restaurant_delivery_provider_id, restaurant_id, delivery_provider_id, is_available,
    minimum_order_amount, base_delivery_charge, delivery_charge_type_code, currency_code, effective_from
) VALUES (
    4013050010001, 401305001, (SELECT delivery_provider_id FROM delivery_provider WHERE provider_code = 'SELF'), TRUE,
    200.00, 0.00, 'fixed', 'INR', (clock_timestamp() AT TIME ZONE 'UTC')
);

-- ---------------------------------------------------------------------
-- Menu board: the JSON is one overall menu with no board label -> one a_la_carte board.
-- ---------------------------------------------------------------------
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, display_sequence) VALUES
    (401305001001, 401305001, 'A La Carte', 'a_la_carte', 1);

-- ---------------------------------------------------------------------
-- Categories (leaf level, JSON order). 26 rows from 28 JSON sections:
--   * pages[1].sections[3] "CHINESE STARTERS & GRAVY (CONTINUED)" is the same section
--     as sections[2] (next column) -> one category; the verbatim "(CONTINUED)" text is
--     kept in menu_item.raw_category_text.
--   * pages[1].sections[13] "RESTAURANT INFORMATION" is the shop-info box, not a menu
--     category -> no menu_category row; its 3 per-kg biryani lines are loaded with
--     menu_category_id NULL + raw_category_text kept (the schema's "needs curation" state).
-- ---------------------------------------------------------------------
INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence) VALUES
    (401305001001, 401305001, 'HOT BEVERAGES', 1),   -- pages[0].sections[0]
    (401305001002, 401305001, 'SOUTH INDIAN SNACKS', 2),   -- pages[0].sections[1]
    (401305001003, 401305001, 'DOSA SPECIALITIES', 3),   -- pages[0].sections[2]
    (401305001004, 401305001, 'SANDWICHES', 4),   -- pages[0].sections[3]
    (401305001005, 401305001, 'UPVAS SPECIAL', 5),   -- pages[0].sections[4]
    (401305001006, 401305001, 'PAV BHAJI', 6),   -- pages[0].sections[5]
    (401305001007, 401305001, 'KOLHAPURI KARAMAT / INDIAN STARTER', 7),   -- pages[0].sections[6]
    (401305001008, 401305001, 'MAIN COURSE (PUNJABI DISHES)', 8),   -- pages[0].sections[7]
    (401305001009, 401305001, 'PANEER SPECIAL DISHES', 9),   -- pages[0].sections[8]
    (401305001010, 401305001, 'MUSHROOM SPECIAL DISHES', 10),   -- pages[0].sections[9]
    (401305001011, 401305001, 'CHOLE SPECIAL', 11),   -- pages[0].sections[10]
    (401305001012, 401305001, 'DAL KI DISHES', 12),   -- pages[0].sections[11]
    (401305001013, 401305001, 'PAPAD', 13),   -- pages[0].sections[12]
    (401305001014, 401305001, 'ROTI KI TOKRI', 14),   -- pages[0].sections[13]
    (401305001015, 401305001, 'RICE', 15),   -- pages[1].sections[0]
    (401305001016, 401305001, 'CHINESE SOUPS', 16),   -- pages[1].sections[1]
    (401305001017, 401305001, 'CHINESE STARTERS & GRAVY', 17),   -- pages[1].sections[2]
    (401305001018, 401305001, 'CHINESE RICE AND NOODLES', 18),   -- pages[1].sections[4]
    (401305001019, 401305001, 'CHINESE TRIPLE RICE', 19),   -- pages[1].sections[5]
    (401305001020, 401305001, 'SALAD (RUSSIAN SALAD, TOSS SALAD)', 20),   -- pages[1].sections[6]
    (401305001021, 401305001, 'COLD BEVERAGES', 21),   -- pages[1].sections[7]
    (401305001022, 401305001, 'COLD DRINKS', 22),   -- pages[1].sections[8]
    (401305001023, 401305001, 'DESSERTS', 23),   -- pages[1].sections[9]
    (401305001024, 401305001, 'MILK SHAKE', 24),   -- pages[1].sections[10]
    (401305001025, 401305001, 'FALOODAS', 25),   -- pages[1].sections[11]
    (401305001026, 401305001, 'FRESH JUICES', 26);   -- pages[1].sections[12]

-- ---------------------------------------------------------------------
-- CANONICAL DISHES (replaces the separate 01_canonical_dish_seed script and its 13-digit ids 4013050010001..184)
--   * 179 dishes referenced by the original script were already correct existing ids (unchanged).
--   * 109 dishes that the original script treated as new are REDUNDANT: the same dish already exists in canonical_dish
--     (same name, same phonetics / different spelling, word order, redundant 'Veg' prefix, serving notes, abbreviations such
--     as 'Spe.' = Special). menu_item.canonical_dish_id points at the existing id (see the trailing comment on each line).
--   * 74 dishes are genuinely new and are created below with ids in the category ranges (10001-90000):
--       veg snacks 10xxx: 10920-10937; egg snacks 11xxx: 11021-11021; paneer 14xxx: 14224-14231; bread 23xxx: 23134-23134; ice cream 40xxx: 40039-40040; drinks 50xxx: 50164-50165; all other 60xxx: 60466-60507
--     NOTE: the 'other veg' range 13001-13999 has no free tail (13999 is used), so new dishes of that category continue in the
--     'all other' range 60xxx, as the earlier 'Veg.' dishes did. canonical_dish_name ids use the standalone 13-digit
--     scheme 4013050010001..4013050010074.
--   * 1 item ('Mushroom', 401305001171) keeps canonical_dish_id NULL: the printed name is truncated (script marks it needs_review).
--   Source of truth: canonical_dish_reconciliation_ashraya_401305001.csv
-- ---------------------------------------------------------------------
INSERT INTO canonical_dish (
    canonical_dish_id, canonical_name, normalized_name, description, food_classification_code,
    default_protein_type_id, is_jain, is_vegan, is_eggless
) VALUES
    (10920, 'Mangalore Sada Dosa', 'mangalore sada dosa', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10921, 'Mangalore Masala Dosa', 'mangalore masala dosa', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10922, 'Chilli Garlic Masala Cheese Dosa', 'chilli garlic masala cheese dosa', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10923, 'Onion Papdi Uttappa', 'onion papdi uttappa', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10924, 'Pizza Uttappa', 'pizza uttappa', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10925, 'Club Grilled Sandwich', 'club grilled sandwich', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10926, 'Mumbai Double Decker Sandwich', 'mumbai double decker sandwich', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10927, 'Veg Mayo Sandwich', 'veg mayo sandwich', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10928, 'Jain Khada Pav Bhaji', 'jain khada pav bhaji', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10929, 'Special Khada Pav Bhaji', 'special khada pav bhaji', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10930, 'Special Jain Pav Bhaji', 'special jain pav bhaji', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10931, 'Jain Masala Pav', 'jain masala pav', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10932, 'Cheese Jain Masala Pav', 'cheese jain masala pav', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10933, 'Saoji Paneer Tikka', 'saoji paneer tikka', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10934, 'Gobi Tikka', 'gobi tikka', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10935, 'Veg Nepali Chilly', 'veg nepali chilly', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10936, 'Paneer Mongolian', 'paneer mongolian', NULL, 'veg', NULL, NULL, NULL, NULL),
    (10937, 'Paneer Nepali Chilly', 'paneer nepali chilly', NULL, 'veg', NULL, NULL, NULL, NULL),
    (11021, 'Tomato Omlet Grilled Sandwich', 'tomato omlet grilled sandwich', NULL, 'veg', NULL, NULL, NULL, NULL),
    (14224, 'Paneer Lasooni Palak', 'paneer lasooni palak', NULL, 'veg', NULL, NULL, NULL, NULL),
    (14225, 'Paneer Agri Masala', 'paneer agri masala', NULL, 'veg', NULL, NULL, NULL, NULL),
    (14226, 'Paneer Saoji Masala', 'paneer saoji masala', NULL, 'veg', NULL, NULL, NULL, NULL),
    (14227, 'Paneer Chop', 'paneer chop', NULL, 'veg', NULL, NULL, NULL, NULL),
    (14228, 'Butter Paneer Paratha', 'butter paneer paratha', NULL, 'veg', NULL, NULL, NULL, NULL),
    (14229, 'Paneer Schezwan Noodles', 'paneer schezwan noodles', NULL, 'veg', NULL, NULL, NULL, NULL),
    (14230, 'Paneer Triple Manchurian Rice', 'paneer triple manchurian rice', NULL, 'veg', NULL, NULL, NULL, NULL),
    (14231, 'Paneer Triple Schezwan Noodles', 'paneer triple schezwan noodles', NULL, 'veg', NULL, NULL, NULL, NULL),
    (23134, 'Butter Garlic Kulcha', 'butter garlic kulcha', NULL, 'veg', NULL, NULL, NULL, NULL),
    (40039, 'Cone Ice Cream', 'cone ice cream', NULL, 'veg', NULL, NULL, NULL, NULL),
    (40040, 'Matka Kulfi', 'matka kulfi', NULL, 'veg', NULL, NULL, NULL, NULL),
    (50164, 'Jeera Masala', 'jeera masala', NULL, 'veg', NULL, NULL, NULL, NULL),
    (50165, 'Rio', 'rio', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60466, 'Zhinge Masala Fry', 'zhinge masala fry', NULL, NULL, NULL, NULL, NULL, NULL),
    (60467, 'Veg Butter Masala', 'veg butter masala', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60468, 'Veg Lababdar', 'veg lababdar', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60469, 'Veg Agri Masala', 'veg agri masala', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60470, 'Veg Saoji Masala', 'veg saoji masala', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60471, 'Punjabi Curry Kofta', 'punjabi curry kofta', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60472, 'Veg Maratha Tadka Kofta', 'veg maratha tadka kofta', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60473, 'Veg Aashraya''s Special', 'veg aashraya''s special', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60474, 'Mushroom Kolhapuri', 'mushroom kolhapuri', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60475, 'Mushroom Jalfrazie', 'mushroom jalfrazie', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60476, 'Mushroom Butter Masala', 'mushroom butter masala', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60477, 'Mushroom Lababdar', 'mushroom lababdar', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60478, 'Mushroom Korma', 'mushroom korma', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60479, 'Mushroom Hyderabadi', 'mushroom hyderabadi', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60480, 'Mushroom Bhuna Masala', 'mushroom bhuna masala', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60481, 'Mushroom Agri Masala', 'mushroom agri masala', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60482, 'Mushroom Saoji Masala', 'mushroom saoji masala', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60483, 'Mushroom Khurchan', 'mushroom khurchan', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60484, 'Butter Dal Fry Tadka', 'butter dal fry tadka', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60485, 'Masoor Dal Fry', 'masoor dal fry', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60486, 'Masoor Dal Fry Tadka', 'masoor dal fry tadka', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60487, 'Khichiya Fried Papad', 'khichiya fried papad', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60488, 'Palak Khichdi Tadka', 'palak khichdi tadka', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60489, 'Khandeshi Khichdi', 'khandeshi khichdi', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60490, 'Indrayani Ghee Rice', 'indrayani ghee rice', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60491, 'Vathwadi Masala Bhat', 'vathwadi masala bhat', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60492, 'Phodnichi Indrayani Bhat', 'phodnichi indrayani bhat', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60493, 'Veg Schezwan Soup', 'veg schezwan soup', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60494, 'Mushroom and Palak Soup', 'mushroom and palak soup', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60495, 'Veg Roast Fried Rice', 'veg roast fried rice', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60496, 'Veg Combination Schezwan Fried Rice', 'veg combination schezwan fried rice', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60497, 'Veg Roast Hakka Noodle', 'veg roast hakka noodle', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60498, 'Veg Peking Noodle', 'veg peking noodle', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60499, 'Veg Triple Manchurian Noodles', 'veg triple manchurian noodles', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60500, 'Veg Triple Manchurian Fried Rice', 'veg triple manchurian fried rice', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60501, 'Veg Triple Nepali Chilly', 'veg triple nepali chilly', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60502, 'Veg Triple Chinese Roast', 'veg triple chinese roast', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60503, 'Veg Triple Peri Peri', 'veg triple peri peri', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60504, 'Veg Triple Butter Pepper', 'veg triple butter pepper', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60505, 'Mushroom Triple Schezwan Rice', 'mushroom triple schezwan rice', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60506, 'Mushroom Triple Manchurian Rice', 'mushroom triple manchurian rice', NULL, 'veg', NULL, NULL, NULL, NULL),
    (60507, 'Mushroom Triple Schezwan Noodles', 'mushroom triple schezwan noodles', NULL, 'veg', NULL, NULL, NULL, NULL);

INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code) VALUES
    (4013050010001, 10920, 'en', 'Mangalore Sada Dosa', 'mangalore sada dosa', 'primary'),
    (4013050010002, 10921, 'en', 'Mangalore Masala Dosa', 'mangalore masala dosa', 'primary'),
    (4013050010003, 10922, 'en', 'Chilli Garlic Masala Cheese Dosa', 'chilli garlic masala cheese dosa', 'primary'),
    (4013050010004, 10923, 'en', 'Onion Papdi Uttappa', 'onion papdi uttappa', 'primary'),
    (4013050010005, 10924, 'en', 'Pizza Uttappa', 'pizza uttappa', 'primary'),
    (4013050010006, 10925, 'en', 'Club Grilled Sandwich', 'club grilled sandwich', 'primary'),
    (4013050010007, 10926, 'en', 'Mumbai Double Decker Sandwich', 'mumbai double decker sandwich', 'primary'),
    (4013050010008, 10927, 'en', 'Veg Mayo Sandwich', 'veg mayo sandwich', 'primary'),
    (4013050010009, 10928, 'en', 'Jain Khada Pav Bhaji', 'jain khada pav bhaji', 'primary'),
    (4013050010010, 10929, 'en', 'Special Khada Pav Bhaji', 'special khada pav bhaji', 'primary'),
    (4013050010011, 10930, 'en', 'Special Jain Pav Bhaji', 'special jain pav bhaji', 'primary'),
    (4013050010012, 10931, 'en', 'Jain Masala Pav', 'jain masala pav', 'primary'),
    (4013050010013, 10932, 'en', 'Cheese Jain Masala Pav', 'cheese jain masala pav', 'primary'),
    (4013050010014, 10933, 'en', 'Saoji Paneer Tikka', 'saoji paneer tikka', 'primary'),
    (4013050010015, 10934, 'en', 'Gobi Tikka', 'gobi tikka', 'primary'),
    (4013050010016, 10935, 'en', 'Veg Nepali Chilly', 'veg nepali chilly', 'primary'),
    (4013050010017, 10936, 'en', 'Paneer Mongolian', 'paneer mongolian', 'primary'),
    (4013050010018, 10937, 'en', 'Paneer Nepali Chilly', 'paneer nepali chilly', 'primary'),
    (4013050010019, 11021, 'en', 'Tomato Omlet Grilled Sandwich', 'tomato omlet grilled sandwich', 'primary'),
    (4013050010020, 14224, 'en', 'Paneer Lasooni Palak', 'paneer lasooni palak', 'primary'),
    (4013050010021, 14225, 'en', 'Paneer Agri Masala', 'paneer agri masala', 'primary'),
    (4013050010022, 14226, 'en', 'Paneer Saoji Masala', 'paneer saoji masala', 'primary'),
    (4013050010023, 14227, 'en', 'Paneer Chop', 'paneer chop', 'primary'),
    (4013050010024, 14228, 'en', 'Butter Paneer Paratha', 'butter paneer paratha', 'primary'),
    (4013050010025, 14229, 'en', 'Paneer Schezwan Noodles', 'paneer schezwan noodles', 'primary'),
    (4013050010026, 14230, 'en', 'Paneer Triple Manchurian Rice', 'paneer triple manchurian rice', 'primary'),
    (4013050010027, 14231, 'en', 'Paneer Triple Schezwan Noodles', 'paneer triple schezwan noodles', 'primary'),
    (4013050010028, 23134, 'en', 'Butter Garlic Kulcha', 'butter garlic kulcha', 'primary'),
    (4013050010029, 40039, 'en', 'Cone Ice Cream', 'cone ice cream', 'primary'),
    (4013050010030, 40040, 'en', 'Matka Kulfi', 'matka kulfi', 'primary'),
    (4013050010031, 50164, 'en', 'Jeera Masala', 'jeera masala', 'primary'),
    (4013050010032, 50165, 'en', 'Rio', 'rio', 'primary'),
    (4013050010033, 60466, 'en', 'Zhinge Masala Fry', 'zhinge masala fry', 'primary'),
    (4013050010034, 60467, 'en', 'Veg Butter Masala', 'veg butter masala', 'primary'),
    (4013050010035, 60468, 'en', 'Veg Lababdar', 'veg lababdar', 'primary'),
    (4013050010036, 60469, 'en', 'Veg Agri Masala', 'veg agri masala', 'primary'),
    (4013050010037, 60470, 'en', 'Veg Saoji Masala', 'veg saoji masala', 'primary'),
    (4013050010038, 60471, 'en', 'Punjabi Curry Kofta', 'punjabi curry kofta', 'primary'),
    (4013050010039, 60472, 'en', 'Veg Maratha Tadka Kofta', 'veg maratha tadka kofta', 'primary'),
    (4013050010040, 60473, 'en', 'Veg Aashraya''s Special', 'veg aashraya''s special', 'primary'),
    (4013050010041, 60474, 'en', 'Mushroom Kolhapuri', 'mushroom kolhapuri', 'primary'),
    (4013050010042, 60475, 'en', 'Mushroom Jalfrazie', 'mushroom jalfrazie', 'primary'),
    (4013050010043, 60476, 'en', 'Mushroom Butter Masala', 'mushroom butter masala', 'primary'),
    (4013050010044, 60477, 'en', 'Mushroom Lababdar', 'mushroom lababdar', 'primary'),
    (4013050010045, 60478, 'en', 'Mushroom Korma', 'mushroom korma', 'primary'),
    (4013050010046, 60479, 'en', 'Mushroom Hyderabadi', 'mushroom hyderabadi', 'primary'),
    (4013050010047, 60480, 'en', 'Mushroom Bhuna Masala', 'mushroom bhuna masala', 'primary'),
    (4013050010048, 60481, 'en', 'Mushroom Agri Masala', 'mushroom agri masala', 'primary'),
    (4013050010049, 60482, 'en', 'Mushroom Saoji Masala', 'mushroom saoji masala', 'primary'),
    (4013050010050, 60483, 'en', 'Mushroom Khurchan', 'mushroom khurchan', 'primary'),
    (4013050010051, 60484, 'en', 'Butter Dal Fry Tadka', 'butter dal fry tadka', 'primary'),
    (4013050010052, 60485, 'en', 'Masoor Dal Fry', 'masoor dal fry', 'primary'),
    (4013050010053, 60486, 'en', 'Masoor Dal Fry Tadka', 'masoor dal fry tadka', 'primary'),
    (4013050010054, 60487, 'en', 'Khichiya Fried Papad', 'khichiya fried papad', 'primary'),
    (4013050010055, 60488, 'en', 'Palak Khichdi Tadka', 'palak khichdi tadka', 'primary'),
    (4013050010056, 60489, 'en', 'Khandeshi Khichdi', 'khandeshi khichdi', 'primary'),
    (4013050010057, 60490, 'en', 'Indrayani Ghee Rice', 'indrayani ghee rice', 'primary'),
    (4013050010058, 60491, 'en', 'Vathwadi Masala Bhat', 'vathwadi masala bhat', 'primary'),
    (4013050010059, 60492, 'en', 'Phodnichi Indrayani Bhat', 'phodnichi indrayani bhat', 'primary'),
    (4013050010060, 60493, 'en', 'Veg Schezwan Soup', 'veg schezwan soup', 'primary'),
    (4013050010061, 60494, 'en', 'Mushroom and Palak Soup', 'mushroom and palak soup', 'primary'),
    (4013050010062, 60495, 'en', 'Veg Roast Fried Rice', 'veg roast fried rice', 'primary'),
    (4013050010063, 60496, 'en', 'Veg Combination Schezwan Fried Rice', 'veg combination schezwan fried rice', 'primary'),
    (4013050010064, 60497, 'en', 'Veg Roast Hakka Noodle', 'veg roast hakka noodle', 'primary'),
    (4013050010065, 60498, 'en', 'Veg Peking Noodle', 'veg peking noodle', 'primary'),
    (4013050010066, 60499, 'en', 'Veg Triple Manchurian Noodles', 'veg triple manchurian noodles', 'primary'),
    (4013050010067, 60500, 'en', 'Veg Triple Manchurian Fried Rice', 'veg triple manchurian fried rice', 'primary'),
    (4013050010068, 60501, 'en', 'Veg Triple Nepali Chilly', 'veg triple nepali chilly', 'primary'),
    (4013050010069, 60502, 'en', 'Veg Triple Chinese Roast', 'veg triple chinese roast', 'primary'),
    (4013050010070, 60503, 'en', 'Veg Triple Peri Peri', 'veg triple peri peri', 'primary'),
    (4013050010071, 60504, 'en', 'Veg Triple Butter Pepper', 'veg triple butter pepper', 'primary'),
    (4013050010072, 60505, 'en', 'Mushroom Triple Schezwan Rice', 'mushroom triple schezwan rice', 'primary'),
    (4013050010073, 60506, 'en', 'Mushroom Triple Manchurian Rice', 'mushroom triple manchurian rice', 'primary'),
    (4013050010074, 60507, 'en', 'Mushroom Triple Schezwan Noodles', 'mushroom triple schezwan noodles', 'primary');

-- ---------------------------------------------------------------------
-- Menu items. food_classification_code = veg for every item (restaurant is pure_veg).
-- is_jain = TRUE only where the printed name says "Jain"; all other dietary flags NULL.
-- split_group_key links dishes that shared one printed line ("A | B", "A / B").
-- canonical_dish_id: an existing canonical_dish id (exact / phonetic / variant match) or a NEW canonical id created in the
-- CANONICAL DISHES section above; NULL only for the truncated 'Mushroom' item.
-- ---------------------------------------------------------------------
INSERT INTO menu_item (
    menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name,
    raw_category_text, food_classification_code, is_jain, split_group_key, verification_status_code
) VALUES
    -- Source: JSON, "pages[0].sections[0]"  (HOT BEVERAGES)
    (401305001001, 401305001, 401305001001, 50154, 'Tea', 'tea', 'HOT BEVERAGES', 'veg', NULL, NULL, 'unverified'),
    (401305001002, 401305001, 401305001001, 50057, 'Filter Coffee', 'filter coffee', 'HOT BEVERAGES', 'veg', NULL, NULL, 'unverified'),
    (401305001003, 401305001, 401305001001, 13622, 'Nes Coffee', 'nes coffee', 'HOT BEVERAGES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010001 (01 seed id) -> existing 13622 'nescafe'
    (401305001004, 401305001, 401305001001, 50109, 'Milk (Cup)', 'milk (cup)', 'HOT BEVERAGES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010002 (01 seed id) -> existing 50109 'milk'
    -- Source: JSON, "pages[0].sections[1]"  (SOUTH INDIAN SNACKS)
    (401305001005, 401305001, 401305001002, 10321, 'Idli', 'idli', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),
    (401305001006, 401305001, 401305001002, 10445, 'Medu Vada', 'medu vada', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),
    (401305001007, 401305001, 401305001002, 10330, 'Idli Vada Mix', 'idli vada mix', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),
    (401305001008, 401305001, 401305001002, 10225, 'Dahi Idli', 'dahi idli', 'SOUTH INDIAN SNACKS', 'veg', NULL, '401305001-P1S2I4', 'unverified'),
    (401305001009, 401305001, 401305001002, 10228, 'Dahi Vada', 'dahi vada', 'SOUTH INDIAN SNACKS', 'veg', NULL, '401305001-P1S2I4', 'unverified'),
    (401305001010, 401305001, 401305001002, 10327, 'Idli Fry', 'idli fry', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),
    (401305001011, 401305001, 401305001002, 10080, 'Butter Idli', 'butter idli', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),
    (401305001012, 401305001, 401305001002, 10286, 'Ghee Podi Idli', 'ghee podi idli', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),
    (401305001013, 401305001, 401305001002, 10690, 'Potato Vada', 'potato vada', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),
    (401305001014, 401305001, 401305001002, 10826, 'Potato Vada Usal', 'potato vada usal', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010003 (01 seed id) -> existing 10826 'vada usal (potato)'
    (401305001015, 401305001, 401305001002, 13879, 'Upma', 'upma', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),
    (401305001016, 401305001, 401305001002, 60115, 'Pineapple Ghee Sheera', 'pineapple ghee sheera', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010004 (01 seed id) -> existing 60115 'pineapple sheera'
    (401305001017, 401305001, 401305001002, 10457, 'Mix Pakoda', 'mix pakoda', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),
    (401305001018, 401305001, 401305001002, 10376, 'Kanda Bhajiya', 'kanda bhajiya', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),
    (401305001019, 401305001, 401305001002, 10872, 'Veg Cutlet', 'veg cutlet', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010005 (01 seed id) -> existing 10872 'veg. cutlet'
    (401305001020, 401305001, 401305001002, 10456, 'Misal Pav', 'misal pav', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),
    (401305001021, 401305001, 401305001002, 10154, 'Cheese Pakoda', 'cheese pakoda', 'SOUTH INDIAN SNACKS', 'veg', NULL, '401305001-P1S2I16', 'unverified'),
    (401305001022, 401305001, 401305001002, 10603, 'Paneer Pakoda', 'paneer pakoda', 'SOUTH INDIAN SNACKS', 'veg', NULL, '401305001-P1S2I16', 'unverified'),
    (401305001023, 401305001, 401305001002, 23092, 'Puri Bhaji', 'puri bhaji', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),
    (401305001024, 401305001, 401305001002, 23091, 'Puri (5 Pcs)', 'puri (5 pcs)', 'SOUTH INDIAN SNACKS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010006 (01 seed id) -> existing 23091 'puri'
    -- Source: JSON, "pages[0].sections[2]"  (DOSA SPECIALITIES)
    (401305001025, 401305001, 401305001003, 10726, 'Sada Dosa', 'sada dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001026, 401305001, 401305001003, 10087, 'Butter Sada Dosa', 'butter sada dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001027, 401305001, 401305001003, 10166, 'Cheese Sada Dosa', 'cheese sada dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001028, 401305001, 401305001003, 10421, 'Masala Dosa', 'masala dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001029, 401305001, 401305001003, 10500, 'Mysore Sada Dosa', 'mysore sada dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001030, 401305001, 401305001003, 10493, 'Mysore Masala Dosa', 'mysore masala dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001031, 401305001, 401305001003, 10708, 'Rava Sada Dosa', 'rava sada dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001032, 401305001, 401305001003, 10705, 'Rava Masala Dosa', 'rava masala dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001033, 401305001, 401305001003, 10611, 'Paneer Sada Dosa', 'paneer sada dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001034, 401305001, 401305001003, 10593, 'Paneer Masala Dosa', 'paneer masala dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001035, 401305001, 401305001003, 10525, 'Onion Sada Dosa', 'onion sada dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001036, 401305001, 401305001003, 10515, 'Onion Masala Dosa', 'onion masala dosa', 'DOSA SPECIALITIES', 'veg', NULL, '401305001-P1S3I12', 'unverified'),
    (401305001037, 401305001, 401305001003, 10522, 'Onion Rava Dosa', 'onion rava dosa', 'DOSA SPECIALITIES', 'veg', NULL, '401305001-P1S3I12', 'unverified'),  -- canonical_dish_id: was 4013050010007 (01 seed id) -> existing 10522 'onion rawa dosa'
    (401305001038, 401305001, 401305001003, 10520, 'Onion Rava Masala Dosa', 'onion rava masala dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001039, 401305001, 401305001003, 10656, 'Paper Sada Dosa', 'paper sada dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001040, 401305001, 401305001003, 10655, 'Paper Masala Dosa', 'paper masala dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001041, 401305001, 401305001003, 10920, 'Mangalore Sada Dosa', 'mangalore sada dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010008 (01 seed id) -> NEW canonical 10920 'Mangalore Sada Dosa'
    (401305001042, 401305001, 401305001003, 10921, 'Mangalore Masala Dosa', 'mangalore masala dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010009 (01 seed id) -> NEW canonical 10921 'Mangalore Masala Dosa'
    (401305001043, 401305001, 401305001003, 10747, 'Schezwan Sada Dosa', 'schezwan sada dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001044, 401305001, 401305001003, 10741, 'Schezwan Masala Dosa', 'schezwan masala dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),
    (401305001045, 401305001, 401305001003, 10922, 'Chilli Garlic Masala Cheese Dosa', 'chilli garlic masala cheese dosa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010010 (01 seed id) -> NEW canonical 10922 'Chilli Garlic Masala Cheese Dosa'
    (401305001046, 401305001, 401305001003, 10682, 'Plain Uttappa', 'plain uttappa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010011 (01 seed id) -> existing 10682 'plain uttapam'
    (401305001047, 401305001, 401305001003, 10529, 'Onion Uttappa', 'onion uttappa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010012 (01 seed id) -> existing 10529 'onion uttapa'
    (401305001048, 401305001, 401305001003, 10923, 'Onion Papdi Uttappa', 'onion papdi uttappa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010013 (01 seed id) -> NEW canonical 10923 'Onion Papdi Uttappa'
    (401305001049, 401305001, 401305001003, 10809, 'Tomato Onion Uttappa', 'tomato onion uttappa', 'DOSA SPECIALITIES', 'veg', NULL, '401305001-P1S3I24', 'unverified'),  -- canonical_dish_id: was 4013050010014 (01 seed id) -> existing 10809 'tomato onion uttapa'
    (401305001050, 401305001, 401305001003, 10432, 'Masala Uttappa', 'masala uttappa', 'DOSA SPECIALITIES', 'veg', NULL, '401305001-P1S3I24', 'unverified'),
    (401305001051, 401305001, 401305001003, 10924, 'Pizza Uttappa', 'pizza uttappa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010015 (01 seed id) -> NEW canonical 10924 'Pizza Uttappa'
    (401305001052, 401305001, 401305001003, 10647, 'Paneer Masala Uttappa', 'paneer masala uttappa', 'DOSA SPECIALITIES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010016 (01 seed id) -> existing 10647 'panner masala uttapa'
    -- Source: JSON, "pages[0].sections[3]"  (SANDWICHES)
    (401305001053, 401305001, 401305001004, 23008, 'Bread Butter', 'bread butter', 'SANDWICHES', 'veg', NULL, NULL, 'unverified'),
    (401305001054, 401305001, 401305001004, 13853, 'Toast Butter', 'toast butter', 'SANDWICHES', 'veg', NULL, NULL, 'unverified'),
    (401305001055, 401305001, 401305001004, 10886, 'Veg Sandwich', 'veg sandwich', 'SANDWICHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010017 (01 seed id) -> existing 10886 'veg. sandwich'
    (401305001056, 401305001, 401305001004, 10836, 'Veg Grilled Sandwich', 'veg grilled sandwich', 'SANDWICHES', 'veg', NULL, NULL, 'unverified'),
    (401305001057, 401305001, 401305001004, 10857, 'Veg Cheese Sandwich', 'veg cheese sandwich', 'SANDWICHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010018 (01 seed id) -> existing 10857 'veg. cheese sandwich'
    (401305001058, 401305001, 401305001004, 10829, 'Veg Cheese Grilled Sandwich', 'veg cheese grilled sandwich', 'SANDWICHES', 'veg', NULL, NULL, 'unverified'),
    (401305001059, 401305001, 401305001004, 11020, 'Tomato Omlet Sandwich', 'tomato omlet sandwich', 'SANDWICHES', 'veg', NULL, NULL, 'needs_review'),
    (401305001060, 401305001, 401305001004, 11021, 'Tomato Omlet Grilled Sandwich', 'tomato omlet grilled sandwich', 'SANDWICHES', 'veg', NULL, NULL, 'needs_review'),  -- canonical_dish_id: was 4013050010019 (01 seed id) -> NEW canonical 11021 'Tomato Omlet Grilled Sandwich'
    (401305001061, 401305001, 401305001004, 10925, 'Club Grilled Sandwich', 'club grilled sandwich', 'SANDWICHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010020 (01 seed id) -> NEW canonical 10925 'Club Grilled Sandwich'
    (401305001062, 401305001, 401305001004, 10926, 'Mumbai Double Decker Sandwich', 'mumbai double decker sandwich', 'SANDWICHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010021 (01 seed id) -> NEW canonical 10926 'Mumbai Double Decker Sandwich'
    (401305001063, 401305001, 401305001004, 10638, 'Paneer Tikka Grilled Sandwich', 'paneer tikka grilled sandwich', 'SANDWICHES', 'veg', NULL, NULL, 'unverified'),
    (401305001064, 401305001, 401305001004, 10927, 'Veg Mayo Sandwich', 'veg mayo sandwich', 'SANDWICHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010022 (01 seed id) -> NEW canonical 10927 'Veg Mayo Sandwich'
    -- Source: JSON, "pages[0].sections[4]"  (UPVAS SPECIAL)
    (401305001065, 401305001, 401305001005, 10721, 'Sabudana Vada', 'sabudana vada', 'UPVAS SPECIAL', 'veg', NULL, NULL, 'unverified'),
    (401305001066, 401305001, 401305001005, 13727, 'Sabudana Khichdi', 'sabudana khichdi', 'UPVAS SPECIAL', 'veg', NULL, NULL, 'unverified'),
    (401305001067, 401305001, 401305001005, 10783, 'Sweet Kachori', 'sweet kachori', 'UPVAS SPECIAL', 'veg', NULL, NULL, 'unverified'),
    (401305001068, 401305001, 401305001005, 10253, 'Finger Chips', 'finger chips', 'UPVAS SPECIAL', 'veg', NULL, NULL, 'unverified'),
    -- Source: JSON, "pages[0].sections[5]"  (PAV BHAJI)
    (401305001069, 401305001, 401305001006, 10658, 'Pav Bhaji', 'pav bhaji', 'PAV BHAJI', 'veg', NULL, NULL, 'unverified'),
    (401305001070, 401305001, 401305001006, 10086, 'Butter Pav Bhaji', 'butter pav bhaji', 'PAV BHAJI', 'veg', NULL, NULL, 'unverified'),
    (401305001071, 401305001, 401305001006, 10161, 'Cheese Pav Bhaji', 'cheese pav bhaji', 'PAV BHAJI', 'veg', NULL, NULL, 'unverified'),
    (401305001072, 401305001, 401305001006, 10383, 'Khada Pav Bhaji', 'khada pav bhaji', 'PAV BHAJI', 'veg', NULL, NULL, 'unverified'),
    (401305001073, 401305001, 401305001006, 10349, 'Jain Pav Bhaji', 'jain pav bhaji', 'PAV BHAJI', 'veg', TRUE, NULL, 'unverified'),
    (401305001074, 401305001, 401305001006, 10928, 'Jain Khada Pav Bhaji', 'jain khada pav bhaji', 'PAV BHAJI', 'veg', TRUE, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010023 (01 seed id) -> NEW canonical 10928 'Jain Khada Pav Bhaji'
    (401305001075, 401305001, 401305001006, 10770, 'Special Pav Bhaji', 'special pav bhaji', 'PAV BHAJI', 'veg', NULL, NULL, 'unverified'),
    (401305001076, 401305001, 401305001006, 10929, 'Special Khada Pav Bhaji', 'special khada pav bhaji', 'PAV BHAJI', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010024 (01 seed id) -> NEW canonical 10929 'Special Khada Pav Bhaji'
    (401305001077, 401305001, 401305001006, 10930, 'Special Jain Pav Bhaji', 'special jain pav bhaji', 'PAV BHAJI', 'veg', TRUE, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010025 (01 seed id) -> NEW canonical 10930 'Special Jain Pav Bhaji'
    (401305001078, 401305001, 401305001006, 10424, 'Masala Pav', 'masala pav', 'PAV BHAJI', 'veg', NULL, NULL, 'unverified'),
    (401305001079, 401305001, 401305001006, 10931, 'Jain Masala Pav', 'jain masala pav', 'PAV BHAJI', 'veg', TRUE, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010026 (01 seed id) -> NEW canonical 10931 'Jain Masala Pav'
    (401305001080, 401305001, 401305001006, 10140, 'Cheese Masala Pav', 'cheese masala pav', 'PAV BHAJI', 'veg', NULL, NULL, 'unverified'),
    (401305001081, 401305001, 401305001006, 10932, 'Cheese Jain Masala Pav', 'cheese jain masala pav', 'PAV BHAJI', 'veg', TRUE, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010027 (01 seed id) -> NEW canonical 10932 'Cheese Jain Masala Pav'
    (401305001082, 401305001, 401305001006, 13632, 'Only Bhaji', 'only bhaji', 'PAV BHAJI', 'veg', NULL, NULL, 'unverified'),
    (401305001083, 401305001, 401305001006, 13385, 'Jain Only Bhaji', 'jain only bhaji', 'PAV BHAJI', 'veg', TRUE, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010028 (01 seed id) -> existing 13385 'jain bhaji'
    (401305001084, 401305001, 401305001006, 10085, 'Butter Pav (1 Pc)', 'butter pav (1 pc)', 'PAV BHAJI', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010029 (01 seed id) -> existing 10085 'butter pav'
    (401305001085, 401305001, 401305001006, 10727, 'Sada Pav (1 Pc)', 'sada pav (1 pc)', 'PAV BHAJI', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010030 (01 seed id) -> existing 10727 'sada pav'
    -- Source: JSON, "pages[0].sections[6]"  (KOLHAPURI KARAMAT / INDIAN STARTER)
    (401305001086, 401305001, 401305001007, 10310, 'Hara Bhara Kebab (Indian Starter)', 'hara bhara kebab (indian starter)', 'KOLHAPURI KARAMAT / INDIAN STARTER', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010031 (01 seed id) -> existing 10310 'hara bhara kabab'
    (401305001087, 401305001, 401305001007, 10589, 'Paneer Malai Tikka (Indian Starter)', 'paneer malai tikka (indian starter)', 'KOLHAPURI KARAMAT / INDIAN STARTER', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010032 (01 seed id) -> existing 10589 'paneer malai tikka'
    (401305001088, 401305001, 401305001007, 10846, 'Veg Seekh Kebab', 'veg seekh kebab', 'KOLHAPURI KARAMAT / INDIAN STARTER', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010033 (01 seed id) -> existing 10846 'veg seekh kabab'
    (401305001089, 401305001, 401305001007, 10631, 'Paneer Tikka', 'paneer tikka', 'KOLHAPURI KARAMAT / INDIAN STARTER', 'veg', NULL, NULL, 'unverified'),
    (401305001090, 401305001, 401305001007, 10602, 'Paneer Pahadi Tikka', 'paneer pahadi tikka', 'KOLHAPURI KARAMAT / INDIAN STARTER', 'veg', NULL, NULL, 'unverified'),
    (401305001091, 401305001, 401305001007, 10609, 'Paneer Pudina Tikka', 'paneer pudina tikka', 'KOLHAPURI KARAMAT / INDIAN STARTER', 'veg', NULL, NULL, 'unverified'),
    (401305001092, 401305001, 401305001007, 14168, 'Paneer Peshawari', 'paneer peshawari', 'KOLHAPURI KARAMAT / INDIAN STARTER', 'veg', NULL, NULL, 'unverified'),
    (401305001093, 401305001, 401305001007, 10933, 'Saoji Paneer Tikka', 'saoji paneer tikka', 'KOLHAPURI KARAMAT / INDIAN STARTER', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010034 (01 seed id) -> NEW canonical 10933 'Saoji Paneer Tikka'
    (401305001094, 401305001, 401305001007, 10582, 'Kalimiri Paneer Tikka', 'kalimiri paneer tikka', 'KOLHAPURI KARAMAT / INDIAN STARTER', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010035 (01 seed id) -> existing 10582 'paneer kalimiri tikka'
    (401305001095, 401305001, 401305001007, 10490, 'Mushroom Tikka', 'mushroom tikka', 'KOLHAPURI KARAMAT / INDIAN STARTER', 'veg', NULL, NULL, 'unverified'),
    (401305001096, 401305001, 401305001007, 10934, 'Gobi Tikka', 'gobi tikka', 'KOLHAPURI KARAMAT / INDIAN STARTER', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010036 (01 seed id) -> NEW canonical 10934 'Gobi Tikka'
    -- Source: JSON, "pages[0].sections[7]"  (MAIN COURSE (PUNJABI DISHES))
    (401305001097, 401305001, 401305001008, 13129, 'Chana Masala', 'chana masala', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I1', 'unverified'),
    (401305001098, 401305001, 401305001008, 13017, 'Alu Mutter', 'alu mutter', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I1', 'unverified'),  -- canonical_dish_id: was 4013050010037 (01 seed id) -> existing 13017 'aloo mutter'
    (401305001099, 401305001, 401305001008, 13692, 'Plain Palak', 'plain palak', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I2', 'unverified'),
    (401305001100, 401305001, 401305001008, 13019, 'Alu Palak', 'alu palak', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I2', 'unverified'),  -- canonical_dish_id: was 4013050010038 (01 seed id) -> existing 13019 'aloo palak'
    (401305001101, 401305001, 401305001008, 13014, 'Alu Gobi', 'alu gobi', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I3', 'unverified'),  -- canonical_dish_id: was 4013050010039 (01 seed id) -> existing 13014 'aloo gobi'
    (401305001102, 401305001, 401305001008, 13015, 'Alu Methi', 'alu methi', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I3', 'unverified'),  -- canonical_dish_id: was 4013050010040 (01 seed id) -> existing 13015 'aloo methi'
    (401305001103, 401305001, 401305001008, 10756, 'Sev Tomato Bhaji', 'sev tomato bhaji', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010041 (01 seed id) -> existing 10756 'sev tomato masala'
    (401305001104, 401305001, 401305001008, 13552, 'Mix Veg', 'mix veg', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I5', 'unverified'),
    (401305001105, 401305001, 401305001008, 60210, 'Veg Khurma', 'veg khurma', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I5', 'unverified'),  -- canonical_dish_id: was 4013050010042 (01 seed id) -> existing 60210 'veg. kurma'
    (401305001106, 401305001, 401305001008, 13075, 'Bhendi Masala', 'bhendi masala', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I6', 'unverified'),
    (401305001107, 401305001, 401305001008, 60466, 'Zhinge Masala Fry', 'zhinge masala fry', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I6', 'needs_review'),  -- canonical_dish_id: was 4013050010043 (01 seed id) -> NEW canonical 60466 'Zhinge Masala Fry'
    (401305001108, 401305001, 401305001008, 13526, 'Methi Mutter Malai', 'methi mutter malai', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I7', 'unverified'),
    (401305001109, 401305001, 401305001008, 13527, 'Methi Mutter Masala', 'methi mutter masala', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I7', 'unverified'),
    (401305001110, 401305001, 401305001008, 60208, 'Veg Kolhapuri', 'veg kolhapuri', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I8', 'unverified'),  -- canonical_dish_id: was 4013050010044 (01 seed id) -> existing 60208 'veg. kolhapuri'
    (401305001111, 401305001, 401305001008, 60196, 'Veg Jaipuri', 'veg jaipuri', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I8', 'unverified'),  -- canonical_dish_id: was 4013050010045 (01 seed id) -> existing 60196 'veg. jaipuri'
    (401305001112, 401305001, 401305001008, 60194, 'Veg Hyderabadi', 'veg hyderabadi', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010046 (01 seed id) -> existing 60194 'veg. hyderabadi'
    (401305001113, 401305001, 401305001008, 60213, 'Veg Makhanwala', 'veg makhanwala', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I10', 'unverified'),  -- canonical_dish_id: was 4013050010047 (01 seed id) -> existing 60213 'veg. makhanwala'
    (401305001114, 401305001, 401305001008, 13914, 'Veg Jalfrazie', 'veg jalfrazie', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I10', 'unverified'),  -- canonical_dish_id: was 4013050010048 (01 seed id) -> existing 13914 'veg jalfrazi'
    (401305001115, 401305001, 401305001008, 60467, 'Veg Butter Masala', 'veg butter masala', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010049 (01 seed id) -> NEW canonical 60467 'Veg Butter Masala'
    (401305001116, 401305001, 401305001008, 60198, 'Veg Kadai', 'veg kadai', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I12', 'unverified'),  -- canonical_dish_id: was 4013050010050 (01 seed id) -> existing 60198 'veg. kadai'
    (401305001117, 401305001, 401305001008, 60180, 'Veg Handi', 'veg handi', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I12', 'unverified'),  -- canonical_dish_id: was 4013050010051 (01 seed id) -> existing 60180 'veg. handi'
    (401305001118, 401305001, 401305001008, 60228, 'Veg Mughlai', 'veg mughlai', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I13', 'unverified'),  -- canonical_dish_id: was 4013050010052 (01 seed id) -> existing 60228 'veg. moglai'
    (401305001119, 401305001, 401305001008, 60205, 'Veg Kheema', 'veg kheema', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I13', 'unverified'),  -- canonical_dish_id: was 4013050010053 (01 seed id) -> existing 60205 'veg. kheema'
    (401305001120, 401305001, 401305001008, 60463, 'Veg Tawa Masala', 'veg tawa masala', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I14', 'unverified'),  -- canonical_dish_id: was 4013050010054 (01 seed id) -> existing 60463 'veg. tava masala'
    (401305001121, 401305001, 401305001008, 60468, 'Veg Lababdar', 'veg lababdar', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I14', 'unverified'),  -- canonical_dish_id: was 4013050010055 (01 seed id) -> NEW canonical 60468 'Veg Lababdar'
    (401305001122, 401305001, 401305001008, 13976, 'Veg Bhuna Masala', 'veg bhuna masala', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010056 (01 seed id) -> existing 13976 'veg. bhuna masala'
    (401305001123, 401305001, 401305001008, 13278, 'Dum Alu Punjabi', 'dum alu punjabi', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010057 (01 seed id) -> existing 13278 'dum aloo punjabi'
    (401305001124, 401305001, 401305001008, 13919, 'Veg Kofta', 'veg kofta', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),
    (401305001125, 401305001, 401305001008, 60217, 'Veg Malwani Masala', 'veg malwani masala', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I18', 'unverified'),  -- canonical_dish_id: was 4013050010058 (01 seed id) -> existing 60217 'veg. malwani'
    (401305001126, 401305001, 401305001008, 60469, 'Veg Agri Masala', 'veg agri masala', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I18', 'unverified'),  -- canonical_dish_id: was 4013050010059 (01 seed id) -> NEW canonical 60469 'Veg Agri Masala'
    (401305001127, 401305001, 401305001008, 60470, 'Veg Saoji Masala', 'veg saoji masala', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010060 (01 seed id) -> NEW canonical 60470 'Veg Saoji Masala'
    (401305001128, 401305001, 401305001008, 13486, 'Malai Kofta', 'malai kofta', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I20', 'unverified'),
    (401305001129, 401305001, 401305001008, 60471, 'Punjabi Curry Kofta', 'punjabi curry kofta', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I20', 'unverified'),  -- canonical_dish_id: was 4013050010061 (01 seed id) -> NEW canonical 60471 'Punjabi Curry Kofta'
    (401305001130, 401305001, 401305001008, 60472, 'Veg Maratha Tadka Kofta', 'veg maratha tadka kofta', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010062 (01 seed id) -> NEW canonical 60472 'Veg Maratha Tadka Kofta'
    (401305001131, 401305001, 401305001008, 13456, 'Lasooni Palak', 'lasooni palak', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),
    (401305001132, 401305001, 401305001008, 60278, 'Veg Tiranga', 'veg tiranga', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010063 (01 seed id) -> existing 60278 'veg. tiranga'
    (401305001133, 401305001, 401305001008, 60473, 'Veg. Aashraya''s Special', 'veg. aashraya''s special', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010064 (01 seed id) -> NEW canonical 60473 'Veg Aashraya''s Special'
    (401305001134, 401305001, 401305001008, 13409, 'Kaju Masala', 'kaju masala', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I25', 'unverified'),
    (401305001135, 401305001, 401305001008, 14010, 'Kaju Paneer Masala', 'kaju paneer masala', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, '401305001-P1S8I25', 'unverified'),
    (401305001136, 401305001, 401305001008, 60240, 'Veg Patiyala', 'veg patiyala', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010065 (01 seed id) -> existing 60240 'veg. patiyala'
    (401305001137, 401305001, 401305001008, 13903, 'Veg Diwani Handi', 'veg diwani handi', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),
    (401305001138, 401305001, 401305001008, 13615, 'Nargis Kofta', 'nargis kofta', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),
    (401305001139, 401305001, 401305001008, 13928, 'Veg Maharaja Special', 'veg maharaja special', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010066 (01 seed id) -> existing 13928 'veg maharaja'
    (401305001140, 401305001, 401305001008, 10866, 'Veg Chilly Milly Special', 'veg chilly milly special', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010067 (01 seed id) -> existing 10866 'veg. chilly milly'
    (401305001141, 401305001, 401305001008, 13905, 'Veg Falguni Special', 'veg falguni special', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010068 (01 seed id) -> existing 13905 'veg falguni'
    (401305001142, 401305001, 401305001008, 13920, 'Veg Koliwada Special', 'veg koliwada special', 'MAIN COURSE (PUNJABI DISHES)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010069 (01 seed id) -> existing 13920 'veg koliwada'
    -- Source: JSON, "pages[0].sections[8]"  (PANEER SPECIAL DISHES)
    (401305001143, 401305001, 401305001009, 14138, 'Paneer Masala', 'paneer masala', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001144, 401305001, 401305001009, 14151, 'Paneer Mutter', 'paneer mutter', 'PANEER SPECIAL DISHES', 'veg', NULL, '401305001-P1S9I2', 'unverified'),
    (401305001145, 401305001, 401305001009, 14045, 'Paneer Chana', 'paneer chana', 'PANEER SPECIAL DISHES', 'veg', NULL, '401305001-P1S9I2', 'unverified'),
    (401305001146, 401305001, 401305001009, 14106, 'Paneer Kolhapuri', 'paneer kolhapuri', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001147, 401305001, 401305001009, 14204, 'Paneer Tikka Masala', 'paneer tikka masala', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001148, 401305001, 401305001009, 14097, 'Paneer Kadai', 'paneer kadai', 'PANEER SPECIAL DISHES', 'veg', NULL, '401305001-P1S9I5', 'needs_review'),
    (401305001149, 401305001, 401305001009, 14072, 'Paneer Handi', 'paneer handi', 'PANEER SPECIAL DISHES', 'veg', NULL, '401305001-P1S9I5', 'needs_review'),
    (401305001150, 401305001, 401305001009, 14096, 'Paneer Jalfrazie', 'paneer jalfrazie', 'PANEER SPECIAL DISHES', 'veg', NULL, '401305001-P1S9I6', 'unverified'),  -- canonical_dish_id: was 4013050010070 (01 seed id) -> existing 14096 'paneer jalfrezi'
    (401305001151, 401305001, 401305001009, 14129, 'Paneer Makhanwala', 'paneer makhanwala', 'PANEER SPECIAL DISHES', 'veg', NULL, '401305001-P1S9I6', 'unverified'),
    (401305001152, 401305001, 401305001009, 14163, 'Paneer Palak', 'paneer palak', 'PANEER SPECIAL DISHES', 'veg', NULL, '401305001-P1S9I7', 'unverified'),
    (401305001153, 401305001, 401305001009, 14224, 'Paneer Lasuni Palak', 'paneer lasuni palak', 'PANEER SPECIAL DISHES', 'veg', NULL, '401305001-P1S9I7', 'unverified'),  -- canonical_dish_id: was 4013050010071 (01 seed id) -> NEW canonical 14224 'Paneer Lasooni Palak'
    (401305001154, 401305001, 401305001009, 14044, 'Paneer Butter Masala', 'paneer butter masala', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001155, 401305001, 401305001009, 14114, 'Paneer Lababdar', 'paneer lababdar', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001156, 401305001, 401305001009, 10629, 'Paneer Tawa Masala', 'paneer tawa masala', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001157, 401305001, 401305001009, 14111, 'Paneer Korma', 'paneer korma', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001158, 401305001, 401305001009, 14086, 'Paneer Hyderabadi', 'paneer hyderabadi', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001159, 401305001, 401305001009, 14034, 'Paneer Bhuna Masala', 'paneer bhuna masala', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001160, 401305001, 401305001009, 14035, 'Paneer Bhurji', 'paneer bhurji', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001161, 401305001, 401305001009, 13134, 'Cheese Butter Masala', 'cheese butter masala', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001162, 401305001, 401305001009, 60421, 'Paneer Malwani Masala', 'paneer malwani masala', 'PANEER SPECIAL DISHES', 'veg', NULL, '401305001-P1S9I16', 'needs_review'),  -- canonical_dish_id: was 4013050010072 (01 seed id) -> existing 60421 'paneer malwani'
    (401305001163, 401305001, 401305001009, 14225, 'Paneer Agri Masala', 'paneer agri masala', 'PANEER SPECIAL DISHES', 'veg', NULL, '401305001-P1S9I16', 'needs_review'),  -- canonical_dish_id: was 4013050010073 (01 seed id) -> NEW canonical 14225 'Paneer Agri Masala'
    (401305001164, 401305001, 401305001009, 14226, 'Paneer Saoji Masala', 'paneer saoji masala', 'PANEER SPECIAL DISHES', 'veg', NULL, '401305001-P1S9I16', 'needs_review'),  -- canonical_dish_id: was 4013050010074 (01 seed id) -> NEW canonical 14226 'Paneer Saoji Masala'
    (401305001165, 401305001, 401305001009, 14103, 'Paneer Kurchan Special', 'paneer kurchan special', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010075 (01 seed id) -> existing 14103 'paneer khurchan'
    (401305001166, 401305001, 401305001009, 10545, 'Paneer Angara', 'paneer angara', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001167, 401305001, 401305001009, 14166, 'Paneer Pasanda', 'paneer pasanda', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001168, 401305001, 401305001009, 14227, 'Paneer Chop Special', 'paneer chop special', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010076 (01 seed id) -> NEW canonical 14227 'Paneer Chop'
    (401305001169, 401305001, 401305001009, 14168, 'Paneer Peshawari Special', 'paneer peshawari special', 'PANEER SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010077 (01 seed id) -> existing 14168 'paneer peshawari'
    -- Source: JSON, "pages[0].sections[9]"  (MUSHROOM SPECIAL DISHES)
    (401305001170, 401305001, 401305001010, 13592, 'Mushroom Masala', 'mushroom masala', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001171, 401305001, 401305001010, NULL, 'Mushroom', 'mushroom', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, NULL, 'needs_review'),  -- FLAG: canonical_dish_id left NULL (was 4013050010078): Item name is just 'Mushroom' (script marks it truncated, confidence 0.5): no canonical dish created or linked
    (401305001172, 401305001, 401305001010, 60474, 'Mushroom Kolhapuri', 'mushroom kolhapuri', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010079 (01 seed id) -> NEW canonical 60474 'Mushroom Kolhapuri'
    (401305001173, 401305001, 401305001010, 13608, 'Mushroom Tikka Masala', 'mushroom tikka masala', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001174, 401305001, 401305001010, 13586, 'Mushroom Kadai', 'mushroom kadai', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, '401305001-P1S10I5', 'needs_review'),
    (401305001175, 401305001, 401305001010, 13581, 'Mushroom Handi', 'mushroom handi', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, '401305001-P1S10I5', 'needs_review'),
    (401305001176, 401305001, 401305001010, 60475, 'Mushroom Jalfrazie', 'mushroom jalfrazie', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010080 (01 seed id) -> NEW canonical 60475 'Mushroom Jalfrazie'
    (401305001177, 401305001, 401305001010, 13588, 'Mushroom Makhanwala', 'mushroom makhanwala', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001178, 401305001, 401305001010, 13598, 'Mushroom Palak', 'mushroom palak', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001179, 401305001, 401305001010, 60476, 'Mushroom Butter Masala', 'mushroom butter masala', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010081 (01 seed id) -> NEW canonical 60476 'Mushroom Butter Masala'
    (401305001180, 401305001, 401305001010, 60477, 'Mushroom Lababdar', 'mushroom lababdar', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010082 (01 seed id) -> NEW canonical 60477 'Mushroom Lababdar'
    (401305001181, 401305001, 401305001010, 10489, 'Mushroom Tawa Masala', 'mushroom tawa masala', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010083 (01 seed id) -> existing 10489 'mushroom tawa'
    (401305001182, 401305001, 401305001010, 60478, 'Mushroom Korma', 'mushroom korma', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, '401305001-P1S10I12', 'needs_review'),  -- canonical_dish_id: was 4013050010084 (01 seed id) -> NEW canonical 60478 'Mushroom Korma'
    (401305001183, 401305001, 401305001010, 13592, 'Mushroom Masala', 'mushroom masala', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, '401305001-P1S10I12', 'needs_review'),
    (401305001184, 401305001, 401305001010, 60479, 'Mushroom Hyderabadi', 'mushroom hyderabadi', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010085 (01 seed id) -> NEW canonical 60479 'Mushroom Hyderabadi'
    (401305001185, 401305001, 401305001010, 60480, 'Mushroom Bhuna Masala', 'mushroom bhuna masala', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010086 (01 seed id) -> NEW canonical 60480 'Mushroom Bhuna Masala'
    (401305001186, 401305001, 401305001010, 13589, 'Mushroom Malwani Masala', 'mushroom malwani masala', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, '401305001-P1S10I15', 'needs_review'),  -- canonical_dish_id: was 4013050010087 (01 seed id) -> existing 13589 'mushroom malvani'
    (401305001187, 401305001, 401305001010, 60481, 'Mushroom Agri Masala', 'mushroom agri masala', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, '401305001-P1S10I15', 'needs_review'),  -- canonical_dish_id: was 4013050010088 (01 seed id) -> NEW canonical 60481 'Mushroom Agri Masala'
    (401305001188, 401305001, 401305001010, 60482, 'Mushroom Saoji Masala', 'mushroom saoji masala', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, '401305001-P1S10I15', 'needs_review'),  -- canonical_dish_id: was 4013050010089 (01 seed id) -> NEW canonical 60482 'Mushroom Saoji Masala'
    (401305001189, 401305001, 401305001010, 60483, 'Mushroom Kurchan Special', 'mushroom kurchan special', 'MUSHROOM SPECIAL DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010090 (01 seed id) -> NEW canonical 60483 'Mushroom Khurchan'
    -- Source: JSON, "pages[0].sections[10]"  (CHOLE SPECIAL)
    (401305001190, 401305001, 401305001011, 23041, 'Chole Bhatura', 'chole bhatura', 'CHOLE SPECIAL', 'veg', NULL, NULL, 'unverified'),
    (401305001191, 401305001, 401305001011, 23007, 'Bhatura (1 pc)', 'bhatura (1 pc)', 'CHOLE SPECIAL', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010091 (01 seed id) -> existing 23007 'bhatura'
    -- Source: JSON, "pages[0].sections[11]"  (DAL KI DISHES)
    (401305001192, 401305001, 401305001012, 13235, 'Dal Fry', 'dal fry', 'DAL KI DISHES', 'veg', NULL, NULL, 'unverified'),
    (401305001193, 401305001, 401305001012, 13238, 'Dal Fry Tadka', 'dal fry tadka', 'DAL KI DISHES', 'veg', NULL, '401305001-P1S12I2', 'unverified'),
    (401305001194, 401305001, 401305001012, 13115, 'Butter Dal Fry', 'butter dal fry', 'DAL KI DISHES', 'veg', NULL, '401305001-P1S12I2', 'unverified'),
    (401305001195, 401305001, 401305001012, 13250, 'Dal Palak', 'dal palak', 'DAL KI DISHES', 'veg', NULL, '401305001-P1S12I3', 'unverified'),
    (401305001196, 401305001, 401305001012, 13245, 'Dal Kolhapuri', 'dal kolhapuri', 'DAL KI DISHES', 'veg', NULL, '401305001-P1S12I3', 'unverified'),
    (401305001197, 401305001, 401305001012, 60484, 'Butter Dal Fry Tadka', 'butter dal fry tadka', 'DAL KI DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010092 (01 seed id) -> NEW canonical 60484 'Butter Dal Fry Tadka'
    (401305001198, 401305001, 401305001012, 60485, 'Masoor Dal Fry Special', 'masoor dal fry special', 'DAL KI DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010093 (01 seed id) -> NEW canonical 60485 'Masoor Dal Fry'
    (401305001199, 401305001, 401305001012, 60486, 'Masoor Dal Fry Tadka', 'masoor dal fry tadka', 'DAL KI DISHES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010094 (01 seed id) -> NEW canonical 60486 'Masoor Dal Fry Tadka'
    -- Source: JSON, "pages[0].sections[12]"  (PAPAD)
    (401305001200, 401305001, 401305001013, 60126, 'Roasted Papad', 'roasted papad', 'PAPAD', 'veg', NULL, '401305001-P1S13I1', 'unverified'),
    (401305001201, 401305001, 401305001013, 60042, 'Fried Papad', 'fried papad', 'PAPAD', 'veg', NULL, '401305001-P1S13I1', 'unverified'),
    (401305001202, 401305001, 401305001013, 60095, 'Masala Papad', 'masala papad', 'PAPAD', 'veg', NULL, NULL, 'unverified'),
    (401305001203, 401305001, 401305001013, 60078, 'Khichcha Papad Roasted', 'khichcha papad roasted', 'PAPAD', 'veg', NULL, '401305001-P1S13I3', 'needs_review'),  -- canonical_dish_id: was 4013050010095 (01 seed id) -> existing 60078 'khichiya roasted papad'
    (401305001204, 401305001, 401305001013, 60487, 'Khichcha Papad Fried', 'khichcha papad fried', 'PAPAD', 'veg', NULL, '401305001-P1S13I3', 'needs_review'),  -- canonical_dish_id: was 4013050010096 (01 seed id) -> NEW canonical 60487 'Khichiya Fried Papad'
    (401305001205, 401305001, 401305001013, 60076, 'Khichcha Masala Papad', 'khichcha masala papad', 'PAPAD', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010097 (01 seed id) -> existing 60076 'khichiya masala papad'
    -- Source: JSON, "pages[0].sections[13]"  (ROTI KI TOKRI)
    (401305001206, 401305001, 401305001014, 23027, 'Chapati', 'chapati', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),
    (401305001207, 401305001, 401305001014, 23013, 'Butter Chapati', 'butter chapati', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),
    (401305001208, 401305001, 401305001014, 23094, 'Roti', 'roti', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),
    (401305001209, 401305001, 401305001014, 23024, 'Butter Roti', 'butter roti', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),
    (401305001210, 401305001, 401305001014, 23080, 'Naan', 'naan', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),
    (401305001211, 401305001, 401305001014, 23020, 'Butter Naan', 'butter naan', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),
    (401305001212, 401305001, 401305001014, 23052, 'Garlic Naan', 'garlic naan', 'ROTI KI TOKRI', 'veg', NULL, '401305001-P1S14I7', 'unverified'),
    (401305001213, 401305001, 401305001014, 23051, 'Garlic Kulcha', 'garlic kulcha', 'ROTI KI TOKRI', 'veg', NULL, '401305001-P1S14I7', 'unverified'),
    (401305001214, 401305001, 401305001014, 23016, 'Butter Garlic Naan', 'butter garlic naan', 'ROTI KI TOKRI', 'veg', NULL, '401305001-P1S14I8', 'unverified'),
    (401305001215, 401305001, 401305001014, 23134, 'Butter Garlic Kulcha', 'butter garlic kulcha', 'ROTI KI TOKRI', 'veg', NULL, '401305001-P1S14I8', 'unverified'),  -- canonical_dish_id: was 4013050010098 (01 seed id) -> NEW canonical 23134 'Butter Garlic Kulcha'
    (401305001216, 401305001, 401305001014, 23061, 'Kulcha', 'kulcha', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),
    (401305001217, 401305001, 401305001014, 23017, 'Butter Kulcha', 'butter kulcha', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),
    (401305001218, 401305001, 401305001014, 23066, 'Laccha Parotha', 'laccha parotha', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010099 (01 seed id) -> existing 23066 'lachcha paratha'
    (401305001219, 401305001, 401305001014, 23018, 'Butter Laccha Parotha', 'butter laccha parotha', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010100 (01 seed id) -> existing 23018 'butter lachewala paratha'
    (401305001220, 401305001, 401305001014, 23003, 'Alu Paratha', 'alu paratha', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010101 (01 seed id) -> existing 23003 'aloo paratha'
    (401305001221, 401305001, 401305001014, 23011, 'Butter Alu Parotha', 'butter alu parotha', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010102 (01 seed id) -> existing 23011 'butter aloo paratha'
    (401305001222, 401305001, 401305001014, 23109, 'Stuff Parotha', 'stuff parotha', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010103 (01 seed id) -> existing 23109 'stuff paratha'
    (401305001223, 401305001, 401305001014, 23025, 'Butter Stuff Parotha', 'butter stuff parotha', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010104 (01 seed id) -> existing 23025 'butter stuffed paratha'
    (401305001224, 401305001, 401305001014, 14165, 'Paneer Parotha', 'paneer parotha', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010105 (01 seed id) -> existing 14165 'paneer paratha'
    (401305001225, 401305001, 401305001014, 14228, 'Butter Paneer Parotha', 'butter paneer parotha', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010106 (01 seed id) -> NEW canonical 14228 'Butter Paneer Paratha'
    (401305001226, 401305001, 401305001014, 23014, 'Butter Cheese Garlic Nan', 'butter cheese garlic nan', 'ROTI KI TOKRI', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010107 (01 seed id) -> existing 23014 'butter cheese garlic naan'
    -- Source: JSON, "pages[1].sections[0]"  (RICE)
    (401305001227, 401305001, 401305001015, 13793, 'Steam Rice', 'steam rice', 'RICE', 'veg', NULL, NULL, 'unverified'),
    (401305001228, 401305001, 401305001015, 13395, 'Jeera Rice', 'jeera rice', 'RICE', 'veg', NULL, NULL, 'unverified'),
    (401305001229, 401305001, 401305001015, 14170, 'Paneer Pulao', 'paneer pulao', 'RICE', 'veg', NULL, NULL, 'unverified'),
    (401305001230, 401305001, 401305001015, 13154, 'Cheese Tawa Pulao', 'cheese tawa pulao', 'RICE', 'veg', NULL, NULL, 'unverified'),
    (401305001231, 401305001, 401305001015, 60290, 'Veg Tawa Pulao', 'veg tawa pulao', 'RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010108 (01 seed id) -> existing 60290 'veg.tawa pulao'
    (401305001232, 401305001, 401305001015, 14198, 'Paneer Tawa Pulao', 'paneer tawa pulao', 'RICE', 'veg', NULL, NULL, 'unverified'),
    (401305001233, 401305001, 401305001015, 14217, 'Cheese Paneer Tawa Pulao', 'cheese paneer tawa pulao', 'RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010109 (01 seed id) -> existing 14217 'spe. paneer cheese tawa pulao'
    (401305001234, 401305001, 401305001015, 60411, 'Mushroom Pulao', 'mushroom pulao', 'RICE', 'veg', NULL, NULL, 'unverified'),
    (401305001235, 401305001, 401305001015, 13570, 'Mushroom Biryani', 'mushroom biryani', 'RICE', 'veg', NULL, NULL, 'unverified'),
    (401305001236, 401305001, 401305001015, 60242, 'Veg Pulao', 'veg pulao', 'RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010110 (01 seed id) -> existing 60242 'veg. pulao'
    (401305001237, 401305001, 401305001015, 13977, 'Veg Biryani', 'veg biryani', 'RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010111 (01 seed id) -> existing 13977 'veg. biryani'
    (401305001238, 401305001, 401305001015, 60195, 'Veg Hyderabadi Biryani', 'veg hyderabadi biryani', 'RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010112 (01 seed id) -> existing 60195 'veg. hyderabadi biryani'
    (401305001239, 401305001, 401305001015, 13242, 'Dal Khichdi', 'dal khichdi', 'RICE', 'veg', NULL, NULL, 'unverified'),
    (401305001240, 401305001, 401305001015, 13243, 'Dal Khichdi Tadka', 'dal khichdi tadka', 'RICE', 'veg', NULL, NULL, 'unverified'),
    (401305001241, 401305001, 401305001015, 13653, 'Palak Khichdi', 'palak khichdi', 'RICE', 'veg', NULL, NULL, 'unverified'),
    (401305001242, 401305001, 401305001015, 60488, 'Palak Khichdi Tadka', 'palak khichdi tadka', 'RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010113 (01 seed id) -> NEW canonical 60488 'Palak Khichdi Tadka'
    (401305001243, 401305001, 401305001015, 13242, 'Veg Dal Khichdi', 'veg dal khichdi', 'RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010114 (01 seed id) -> existing 13242 'dal khichdi'
    (401305001244, 401305001, 401305001015, 60489, 'Khandeshi Khichdi', 'khandeshi khichdi', 'RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010115 (01 seed id) -> NEW canonical 60489 'Khandeshi Khichdi'
    (401305001245, 401305001, 401305001015, 60490, 'Indrayani Ghee Rice', 'indrayani ghee rice', 'RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010116 (01 seed id) -> NEW canonical 60490 'Indrayani Ghee Rice'
    (401305001246, 401305001, 401305001015, 60491, 'Vathwadi Masala Bhat', 'vathwadi masala bhat', 'RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010117 (01 seed id) -> NEW canonical 60491 'Vathwadi Masala Bhat'
    (401305001247, 401305001, 401305001015, 60492, 'Phodnichi Indrayani Bhat', 'phodnichi indrayani bhat', 'RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010118 (01 seed id) -> NEW canonical 60492 'Phodnichi Indrayani Bhat'
    (401305001248, 401305001, 401305001015, 14038, 'Paneer Biryani', 'paneer biryani', 'RICE', 'veg', NULL, NULL, 'unverified'),
    (401305001249, 401305001, 401305001015, 14202, 'Paneer Tikka Biryani', 'paneer tikka biryani', 'RICE', 'veg', NULL, NULL, 'unverified'),
    -- Source: JSON, "pages[1].sections[1]"  (CHINESE SOUPS)
    (401305001250, 401305001, 401305001016, 13865, 'Tomato Soup', 'tomato soup', 'CHINESE SOUPS', 'veg', NULL, '401305001-P2S2I1', 'unverified'),
    (401305001251, 401305001, 401305001016, 13662, 'Palak Soup', 'palak soup', 'CHINESE SOUPS', 'veg', NULL, '401305001-P2S2I1', 'unverified'),
    (401305001252, 401305001, 401305001016, 13899, 'Veg Clear Soup', 'veg clear soup', 'CHINESE SOUPS', 'veg', NULL, NULL, 'unverified'),
    (401305001253, 401305001, 401305001016, 60493, 'Veg Schezwan Soup', 'veg schezwan soup', 'CHINESE SOUPS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010119 (01 seed id) -> NEW canonical 60493 'Veg Schezwan Soup'
    (401305001254, 401305001, 401305001016, 60191, 'Veg Hot and Sour Soup', 'veg hot and sour soup', 'CHINESE SOUPS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010120 (01 seed id) -> existing 60191 'veg. hot & sour soup'
    (401305001255, 401305001, 401305001016, 60494, 'Mushroom and Palak Soup', 'mushroom and palak soup', 'CHINESE SOUPS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010121 (01 seed id) -> NEW canonical 60494 'Mushroom and Palak Soup'
    (401305001256, 401305001, 401305001016, 13462, 'Lemon Coriander', 'lemon coriander', 'CHINESE SOUPS', 'veg', NULL, NULL, 'unverified'),
    (401305001257, 401305001, 401305001016, 13603, 'Mushroom Soup', 'mushroom soup', 'CHINESE SOUPS', 'veg', NULL, NULL, 'unverified'),
    -- Source: JSON, "pages[1].sections[2]"  (CHINESE STARTERS & GRAVY)
    (401305001258, 401305001, 401305001017, 10196, 'Chinese Bhel', 'chinese bhel', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),
    (401305001259, 401305001, 401305001017, 10325, 'Idli Chilly', 'idli chilly', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),
    (401305001260, 401305001, 401305001017, 10766, 'Soyabean Chilly', 'soyabean chilly', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),
    (401305001261, 401305001, 401305001017, 10871, 'Veg Crispy', 'veg crispy', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010122 (01 seed id) -> existing 10871 'veg. crispy'
    (401305001262, 401305001, 401305001017, 10849, 'Veg 65', 'veg 65', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010123 (01 seed id) -> existing 10849 'veg. 65'
    (401305001263, 401305001, 401305001017, 60248, 'Veg Schezwan', 'veg schezwan', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010124 (01 seed id) -> existing 60248 'veg. schezwan'
    (401305001264, 401305001, 401305001017, 60192, 'Veg Hot Garlic', 'veg hot garlic', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010125 (01 seed id) -> existing 60192 'veg. hot garlic'
    (401305001265, 401305001, 401305001017, 60185, 'Veg Hong Kong', 'veg hong kong', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010126 (01 seed id) -> existing 60185 'veg. hong kong'
    (401305001266, 401305001, 401305001017, 10935, 'Veg Nepali Chilly', 'veg nepali chilly', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010127 (01 seed id) -> NEW canonical 10935 'Veg Nepali Chilly'
    (401305001267, 401305001, 401305001017, 10880, 'Veg Manchurian', 'veg manchurian', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010128 (01 seed id) -> existing 10880 'veg. manchurian'
    (401305001268, 401305001, 401305001017, 10833, 'Veg Chilly', 'veg chilly', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),
    (401305001269, 401305001, 401305001017, 10591, 'Paneer Manchurian', 'paneer manchurian', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),
    (401305001270, 401305001, 401305001017, 10936, 'Paneer Mongolian', 'paneer mongolian', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010129 (01 seed id) -> NEW canonical 10936 'Paneer Mongolian'
    (401305001271, 401305001, 401305001017, 10563, 'Paneer Chilly', 'paneer chilly', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),
    (401305001272, 401305001, 401305001017, 10571, 'Paneer Crispy', 'paneer crispy', 'CHINESE STARTERS & GRAVY', 'veg', NULL, NULL, 'unverified'),
    -- Source: JSON, "pages[1].sections[3]"  (CHINESE STARTERS & GRAVY (CONTINUED))
    (401305001273, 401305001, 401305001017, 14179, 'Paneer Schezwan', 'paneer schezwan', 'CHINESE STARTERS & GRAVY (CONTINUED)', 'veg', NULL, NULL, 'unverified'),
    (401305001274, 401305001, 401305001017, 10540, 'Paneer 65', 'paneer 65', 'CHINESE STARTERS & GRAVY (CONTINUED)', 'veg', NULL, NULL, 'unverified'),
    (401305001275, 401305001, 401305001017, 14083, 'Paneer Hot Garlic', 'paneer hot garlic', 'CHINESE STARTERS & GRAVY (CONTINUED)', 'veg', NULL, NULL, 'unverified'),
    (401305001276, 401305001, 401305001017, 14078, 'Paneer Hong Kong', 'paneer hong kong', 'CHINESE STARTERS & GRAVY (CONTINUED)', 'veg', NULL, NULL, 'unverified'),
    (401305001277, 401305001, 401305001017, 10937, 'Paneer Nepali Chilly', 'paneer nepali chilly', 'CHINESE STARTERS & GRAVY (CONTINUED)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010130 (01 seed id) -> NEW canonical 10937 'Paneer Nepali Chilly'
    (401305001278, 401305001, 401305001017, 10481, 'Mushroom Manchurian', 'mushroom manchurian', 'CHINESE STARTERS & GRAVY (CONTINUED)', 'veg', NULL, NULL, 'unverified'),
    (401305001279, 401305001, 401305001017, 10476, 'Mushroom Chilly', 'mushroom chilly', 'CHINESE STARTERS & GRAVY (CONTINUED)', 'veg', NULL, '401305001-P2S4I7', 'unverified'),
    (401305001280, 401305001, 401305001017, 10044, 'Baby Corn Chilly', 'baby corn chilly', 'CHINESE STARTERS & GRAVY (CONTINUED)', 'veg', NULL, '401305001-P2S4I7', 'unverified'),
    (401305001281, 401305001, 401305001017, 10469, 'Mushroom and Baby Corn Chilly', 'mushroom and baby corn chilly', 'CHINESE STARTERS & GRAVY (CONTINUED)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010131 (01 seed id) -> existing 10469 'mushroom babycorn chilli'
    -- Source: JSON, "pages[1].sections[4]"  (CHINESE RICE AND NOODLES)
    (401305001282, 401305001, 401305001018, 60168, 'Veg. Fried Rice', 'veg. fried rice', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),
    (401305001283, 401305001, 401305001018, 14069, 'Paneer Fried Rice', 'paneer fried rice', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),
    (401305001284, 401305001, 401305001018, 14181, 'Paneer Schezwan Fried Rice', 'paneer schezwan fried rice', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),
    (401305001285, 401305001, 401305001018, 60249, 'Veg Schezwan Fried Rice', 'veg schezwan fried rice', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010132 (01 seed id) -> existing 60249 'veg. schezwan fried rice'
    (401305001286, 401305001, 401305001018, 60495, 'Veg. Roast Fried Rice', 'veg. roast fried rice', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010133 (01 seed id) -> NEW canonical 60495 'Veg Roast Fried Rice'
    (401305001287, 401305001, 401305001018, 13110, 'Veg. Burnt Garlic Fried Rice', 'veg. burnt garlic fried rice', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010134 (01 seed id) -> existing 13110 'burnt garlic fried rice'
    (401305001288, 401305001, 401305001018, 60260, 'Veg Singapore Fried Rice', 'veg singapore fried rice', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010135 (01 seed id) -> existing 60260 'veg. singapore fried rice'
    (401305001289, 401305001, 401305001018, 60186, 'Veg Hong Kong Fried Rice', 'veg hong kong fried rice', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010136 (01 seed id) -> existing 60186 'veg. hong kong fried rice'
    (401305001290, 401305001, 401305001018, 60159, 'Veg Combination Fried Rice', 'veg combination fried rice', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010137 (01 seed id) -> existing 60159 'veg. combination fried rice'
    (401305001291, 401305001, 401305001018, 60496, 'Veg Combination Schezwan Fried Rice', 'veg combination schezwan fried rice', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010138 (01 seed id) -> NEW canonical 60496 'Veg Combination Schezwan Fried Rice'
    (401305001292, 401305001, 401305001018, 60179, 'Veg Hakka Noodle', 'veg hakka noodle', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010139 (01 seed id) -> existing 60179 'veg. hakka noodles'
    (401305001293, 401305001, 401305001018, 60251, 'Veg Schezwan Noodle', 'veg schezwan noodle', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010140 (01 seed id) -> existing 60251 'veg. schezwan noodles'
    (401305001294, 401305001, 401305001018, 14156, 'Paneer Hakka Noodles', 'paneer hakka noodles', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010141 (01 seed id) -> existing 14156 'paneer noodles'
    (401305001295, 401305001, 401305001018, 14229, 'Paneer Schezwan Noodles', 'paneer schezwan noodles', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010142 (01 seed id) -> NEW canonical 14229 'Paneer Schezwan Noodles'
    (401305001296, 401305001, 401305001018, 60497, 'Veg. Roast Hakka Noodle', 'veg. roast hakka noodle', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010143 (01 seed id) -> NEW canonical 60497 'Veg Roast Hakka Noodle'
    (401305001297, 401305001, 401305001018, 13988, 'Veg. Burnt Garlic Noodle', 'veg. burnt garlic noodle', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010144 (01 seed id) -> existing 13988 'veg. burnt garlic noodles'
    (401305001298, 401305001, 401305001018, 60498, 'Veg Peking Noodle', 'veg peking noodle', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010145 (01 seed id) -> NEW canonical 60498 'Veg Peking Noodle'
    (401305001299, 401305001, 401305001018, 60261, 'Veg Singapore Noodle', 'veg singapore noodle', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010146 (01 seed id) -> existing 60261 'veg. singapore noodles'
    (401305001300, 401305001, 401305001018, 13366, 'Veg Hong Kong Noodle', 'veg hong kong noodle', 'CHINESE RICE AND NOODLES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010147 (01 seed id) -> existing 13366 'hong kong noodles (veg)'
    -- Source: JSON, "pages[1].sections[5]"  (CHINESE TRIPLE RICE)
    (401305001301, 401305001, 401305001019, 60283, 'Veg Triple Schezwan Fried Rice', 'veg triple schezwan fried rice', 'CHINESE TRIPLE RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010148 (01 seed id) -> existing 60283 'veg. triple schezwan fried rice'
    (401305001302, 401305001, 401305001019, 60499, 'Veg Triple Manchurian Noodles', 'veg triple manchurian noodles', 'CHINESE TRIPLE RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010149 (01 seed id) -> NEW canonical 60499 'Veg Triple Manchurian Noodles'
    (401305001303, 401305001, 401305001019, 60500, 'Veg Triple Manchurian Fried Rice', 'veg triple manchurian fried rice', 'CHINESE TRIPLE RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010150 (01 seed id) -> NEW canonical 60500 'Veg Triple Manchurian Fried Rice'
    (401305001304, 401305001, 401305001019, 60501, 'Veg Triple Nepali Chilly', 'veg triple nepali chilly', 'CHINESE TRIPLE RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010151 (01 seed id) -> NEW canonical 60501 'Veg Triple Nepali Chilly'
    (401305001305, 401305001, 401305001019, 60502, 'Veg Triple Chinese Roast', 'veg triple chinese roast', 'CHINESE TRIPLE RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010152 (01 seed id) -> NEW canonical 60502 'Veg Triple Chinese Roast'
    (401305001306, 401305001, 401305001019, 60503, 'Veg Triple Peri Peri', 'veg triple peri peri', 'CHINESE TRIPLE RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010153 (01 seed id) -> NEW canonical 60503 'Veg Triple Peri Peri'
    (401305001307, 401305001, 401305001019, 60504, 'Veg Triple Butter Pepper', 'veg triple butter pepper', 'CHINESE TRIPLE RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010154 (01 seed id) -> NEW canonical 60504 'Veg Triple Butter Pepper'
    (401305001308, 401305001, 401305001019, 14208, 'Paneer Triple Schezwan Rice', 'paneer triple schezwan rice', 'CHINESE TRIPLE RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010155 (01 seed id) -> existing 14208 'paneer triple schezwan fried rice'
    (401305001309, 401305001, 401305001019, 14230, 'Paneer Triple Manchurian Rice', 'paneer triple manchurian rice', 'CHINESE TRIPLE RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010156 (01 seed id) -> NEW canonical 14230 'Paneer Triple Manchurian Rice'
    (401305001310, 401305001, 401305001019, 14231, 'Paneer Triple Schezwan Noodles', 'paneer triple schezwan noodles', 'CHINESE TRIPLE RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010157 (01 seed id) -> NEW canonical 14231 'Paneer Triple Schezwan Noodles'
    (401305001311, 401305001, 401305001019, 60505, 'Mushroom Triple Schezwan Rice', 'mushroom triple schezwan rice', 'CHINESE TRIPLE RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010158 (01 seed id) -> NEW canonical 60505 'Mushroom Triple Schezwan Rice'
    (401305001312, 401305001, 401305001019, 60506, 'Mushroom Triple Manchurian Rice', 'mushroom triple manchurian rice', 'CHINESE TRIPLE RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010159 (01 seed id) -> NEW canonical 60506 'Mushroom Triple Manchurian Rice'
    (401305001313, 401305001, 401305001019, 60507, 'Mushroom Triple Schezwan Noodles', 'mushroom triple schezwan noodles', 'CHINESE TRIPLE RICE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010160 (01 seed id) -> NEW canonical 60507 'Mushroom Triple Schezwan Noodles'
    -- Source: JSON, "pages[1].sections[6]"  (SALAD (RUSSIAN SALAD, TOSS SALAD))
    (401305001314, 401305001, 401305001020, 60061, 'Green Salad', 'green salad', 'SALAD (RUSSIAN SALAD, TOSS SALAD)', 'veg', NULL, NULL, 'unverified'),
    (401305001315, 401305001, 401305001020, 60114, 'Pineapple Raitha', 'pineapple raitha', 'SALAD (RUSSIAN SALAD, TOSS SALAD)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010161 (01 seed id) -> existing 60114 'pineapple raita'
    (401305001316, 401305001, 401305001020, 60150, 'Tomato Salad', 'tomato salad', 'SALAD (RUSSIAN SALAD, TOSS SALAD)', 'veg', NULL, NULL, 'unverified'),
    (401305001317, 401305001, 401305001020, 60244, 'Veg Raitha', 'veg raitha', 'SALAD (RUSSIAN SALAD, TOSS SALAD)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010162 (01 seed id) -> existing 60244 'veg. raita'
    (401305001318, 401305001, 401305001020, 13218, 'Curd', 'curd', 'SALAD (RUSSIAN SALAD, TOSS SALAD)', 'veg', NULL, NULL, 'unverified'),
    (401305001319, 401305001, 401305001020, 60016, 'Boondi Raitha', 'boondi raitha', 'SALAD (RUSSIAN SALAD, TOSS SALAD)', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010163 (01 seed id) -> existing 60016 'boondi raita'
    -- Source: JSON, "pages[1].sections[7]"  (COLD BEVERAGES)
    (401305001320, 401305001, 401305001021, 51015, 'Virgin Mojito', 'virgin mojito', 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified'),
    (401305001321, 401305001, 401305001021, 50062, 'Fresh Lime Water', 'fresh lime water', 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified'),
    (401305001322, 401305001, 401305001021, 50061, 'Fresh Lime Soda', 'fresh lime soda', 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified'),
    (401305001323, 401305001, 401305001021, 50164, 'Jeera Masala', 'jeera masala', 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010164 (01 seed id) -> NEW canonical 50164 'Jeera Masala'
    (401305001324, 401305001, 401305001021, 50102, 'Mango Lassi', 'mango lassi', 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified'),
    (401305001325, 401305001, 401305001021, 50091, 'Lassi', 'lassi', 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified'),
    (401305001326, 401305001, 401305001021, 50025, 'Butter Milk', 'butter milk', 'COLD BEVERAGES', 'veg', NULL, NULL, 'unverified'),
    -- Source: JSON, "pages[1].sections[8]"  (COLD DRINKS)
    (401305001327, 401305001, 401305001022, 13717, 'Red Bull', 'red bull', 'COLD DRINKS', 'veg', NULL, NULL, 'unverified'),
    (401305001328, 401305001, 401305001022, 50143, 'Soft Drink 500 ml', 'soft drink 500 ml', 'COLD DRINKS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010165 (01 seed id) -> existing 50143 'soft drinks'
    (401305001329, 401305001, 401305001022, 50143, 'Soft Drink 250 ml', 'soft drink 250 ml', 'COLD DRINKS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010166 (01 seed id) -> existing 50143 'soft drinks'
    (401305001330, 401305001, 401305001022, 50165, 'Rio', 'rio', 'COLD DRINKS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010167 (01 seed id) -> NEW canonical 50165 'Rio'
    (401305001331, 401305001, 401305001022, 50110, 'Mineral Water 500 ml', 'mineral water 500 ml', 'COLD DRINKS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010168 (01 seed id) -> existing 50110 'mineral water'
    (401305001332, 401305001, 401305001022, 50110, 'Mineral Water 1 L', 'mineral water 1 l', 'COLD DRINKS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010169 (01 seed id) -> existing 50110 'mineral water'
    -- Source: JSON, "pages[1].sections[9]"  (DESSERTS)
    (401305001333, 401305001, 401305001023, 60062, 'Gulab Jamun', 'gulab jamun', 'DESSERTS', 'veg', NULL, NULL, 'unverified'),
    (401305001334, 401305001, 401305001023, 60064, 'Gulab Jamun with Ice Cream', 'gulab jamun with ice cream', 'DESSERTS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010170 (01 seed id) -> existing 60064 'gulab jamun with vanilla ice cream'
    (401305001335, 401305001, 401305001023, 40038, 'Vanila Ice Cream Scoop', 'vanila ice cream scoop', 'DESSERTS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010171 (01 seed id) -> existing 40038 'vanilla ice cream'
    (401305001336, 401305001, 401305001023, 60145, 'Strawberry Ice Cream Scoop', 'strawberry ice cream scoop', 'DESSERTS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010172 (01 seed id) -> existing 60145 'strawberry ice cream'
    (401305001337, 401305001, 401305001023, 40005, 'Butter Scotch Ice Cream Scoop', 'butter scotch ice cream scoop', 'DESSERTS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010173 (01 seed id) -> existing 40005 'butter scotch'
    (401305001338, 401305001, 401305001023, 60085, 'Mango Ice Cream Scoop', 'mango ice cream scoop', 'DESSERTS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010174 (01 seed id) -> existing 60085 'mango'
    (401305001339, 401305001, 401305001023, 60378, 'Choco Chips Ice Cream Scoop', 'choco chips ice cream scoop', 'DESSERTS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010175 (01 seed id) -> existing 60378 'choco chips'
    (401305001340, 401305001, 401305001023, 40039, 'Cones Ice Cream', 'cones ice cream', 'DESSERTS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010176 (01 seed id) -> NEW canonical 40039 'Cone Ice Cream'
    (401305001341, 401305001, 401305001023, 40040, 'Matka Kulfi', 'matka kulfi', 'DESSERTS', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010177 (01 seed id) -> NEW canonical 40040 'Matka Kulfi'
    (401305001342, 401305001, 401305001023, 30013, 'Sizzling Brownie', 'sizzling brownie', 'DESSERTS', 'veg', NULL, NULL, 'unverified'),
    -- Source: JSON, "pages[1].sections[10]"  (MILK SHAKE)
    (401305001343, 401305001, 401305001024, 50162, 'Vanilla Milk Shake', 'vanilla milk shake', 'MILK SHAKE', 'veg', NULL, NULL, 'unverified'),
    (401305001344, 401305001, 401305001024, 50149, 'Strawberry Milk Shake', 'strawberry milk shake', 'MILK SHAKE', 'veg', NULL, NULL, 'unverified'),
    (401305001345, 401305001, 401305001024, 50036, 'Chocolate Milk Shake', 'chocolate milk shake', 'MILK SHAKE', 'veg', NULL, NULL, 'unverified'),
    (401305001346, 401305001, 401305001024, 50030, 'Butter Scotch Milk Shake', 'butter scotch milk shake', 'MILK SHAKE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010178 (01 seed id) -> existing 50030 'butter scotch shake'
    (401305001347, 401305001, 401305001024, 50104, 'Mango Milk Shake', 'mango milk shake', 'MILK SHAKE', 'veg', NULL, NULL, 'unverified'),
    (401305001348, 401305001, 401305001024, 50034, 'Chickoo Milk Shake', 'chickoo milk shake', 'MILK SHAKE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010179 (01 seed id) -> existing 50034 'chikku milk shake'
    (401305001349, 401305001, 401305001024, 50013, 'Banana Milk Shake', 'banana milk shake', 'MILK SHAKE', 'veg', NULL, NULL, 'unverified'),
    (401305001350, 401305001, 401305001024, 50053, 'Dry Fruits Milk Shake', 'dry fruits milk shake', 'MILK SHAKE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010180 (01 seed id) -> existing 50053 'dry fruit milk shake'
    (401305001351, 401305001, 401305001024, 50040, 'Cold Coffee', 'cold coffee', 'MILK SHAKE', 'veg', NULL, NULL, 'unverified'),
    (401305001352, 401305001, 401305001024, 50042, 'Cold Coffee with Ice Cream', 'cold coffee with ice cream', 'MILK SHAKE', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010181 (01 seed id) -> existing 50042 'cold coffee with ice-cream'
    -- Source: JSON, "pages[1].sections[11]"  (FALOODAS)
    (401305001353, 401305001, 401305001025, 50133, 'Royal Falooda', 'royal falooda', 'FALOODAS', 'veg', NULL, NULL, 'unverified'),
    (401305001354, 401305001, 401305001025, 50029, 'Butter Scotch Falooda', 'butter scotch falooda', 'FALOODAS', 'veg', NULL, NULL, 'unverified'),
    (401305001355, 401305001, 401305001025, 50081, 'Kesar Falooda', 'kesar falooda', 'FALOODAS', 'veg', NULL, NULL, 'unverified'),
    (401305001356, 401305001, 401305001025, 50147, 'Strawberry Falooda', 'strawberry falooda', 'FALOODAS', 'veg', NULL, NULL, 'unverified'),
    (401305001357, 401305001, 401305001025, 50050, 'Dry Fruit Falooda', 'dry fruit falooda', 'FALOODAS', 'veg', NULL, NULL, 'unverified'),
    -- Source: JSON, "pages[1].sections[12]"  (FRESH JUICES)
    (401305001358, 401305001, 401305001026, 60104, 'Orange', 'orange', 'FRESH JUICES', 'veg', NULL, NULL, 'unverified'),
    (401305001359, 401305001, 401305001026, 60102, 'Mosambi', 'mosambi', 'FRESH JUICES', 'veg', NULL, NULL, 'unverified'),
    (401305001360, 401305001, 401305001026, 60110, 'Pineapple', 'pineapple', 'FRESH JUICES', 'veg', NULL, NULL, 'unverified'),
    (401305001361, 401305001, 401305001026, 60331, 'Watermelon', 'watermelon', 'FRESH JUICES', 'veg', NULL, NULL, 'unverified'),
    -- Source: JSON, "pages[1].sections[13]"  (RESTAURANT INFORMATION)
    (401305001362, 401305001, NULL, 13977, 'Special Biryani (Per Kg) - Veg Biryani', 'special biryani (per kg) - veg biryani', 'RESTAURANT INFORMATION', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010182 (01 seed id) -> existing 13977 'veg. biryani'
    (401305001363, 401305001, NULL, 14038, 'Special Biryani (Per Kg) - Paneer Biryani', 'special biryani (per kg) - paneer biryani', 'RESTAURANT INFORMATION', 'veg', NULL, NULL, 'unverified'),  -- canonical_dish_id: was 4013050010183 (01 seed id) -> existing 14038 'paneer biryani'
    (401305001364, 401305001, NULL, 14202, 'Special Biryani (Per Kg) - Paneer Tikka Biryani', 'special biryani (per kg) - paneer tikka biryani', 'RESTAURANT INFORMATION', 'veg', NULL, NULL, 'unverified');  -- canonical_dish_id: was 4013050010184 (01 seed id) -> existing 14202 'paneer tikka biryani'

-- ---------------------------------------------------------------------
-- Variants. Portion variants stay under ONE item (Steam Rice Half/Full).
-- Everything else has one "Regular" variant, except lines whose printed name carries an
-- explicit quantity token (Pcs / ml / L / Per Kg) -> that quantity is recorded.
-- ---------------------------------------------------------------------
INSERT INTO menu_item_variant (
    variant_id, menu_item_id, variant_name, pricing_basis_code, quantity_value, quantity_unit_code, display_sequence, is_default
) VALUES
    -- Source: JSON, "pages[0].sections[0]"  (HOT BEVERAGES)
    (401305001001, 401305001001, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001002, 401305001002, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001003, 401305001003, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001004, 401305001004, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[0].sections[1]"  (SOUTH INDIAN SNACKS)
    (401305001005, 401305001005, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001006, 401305001006, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001007, 401305001007, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001008, 401305001008, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001009, 401305001009, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001010, 401305001010, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001011, 401305001011, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001012, 401305001012, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001013, 401305001013, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001014, 401305001014, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001015, 401305001015, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001016, 401305001016, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001017, 401305001017, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001018, 401305001018, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001019, 401305001019, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001020, 401305001020, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001021, 401305001021, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001022, 401305001022, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001023, 401305001023, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001024, 401305001024, '5 Pcs', 'fixed', 5, 'pieces', 1, TRUE),
    -- Source: JSON, "pages[0].sections[2]"  (DOSA SPECIALITIES)
    (401305001025, 401305001025, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001026, 401305001026, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001027, 401305001027, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001028, 401305001028, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001029, 401305001029, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001030, 401305001030, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001031, 401305001031, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001032, 401305001032, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001033, 401305001033, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001034, 401305001034, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001035, 401305001035, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001036, 401305001036, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001037, 401305001037, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001038, 401305001038, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001039, 401305001039, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001040, 401305001040, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001041, 401305001041, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001042, 401305001042, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001043, 401305001043, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001044, 401305001044, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001045, 401305001045, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001046, 401305001046, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001047, 401305001047, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001048, 401305001048, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001049, 401305001049, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001050, 401305001050, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001051, 401305001051, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001052, 401305001052, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[0].sections[3]"  (SANDWICHES)
    (401305001053, 401305001053, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001054, 401305001054, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001055, 401305001055, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001056, 401305001056, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001057, 401305001057, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001058, 401305001058, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001059, 401305001059, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001060, 401305001060, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001061, 401305001061, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001062, 401305001062, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001063, 401305001063, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001064, 401305001064, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[0].sections[4]"  (UPVAS SPECIAL)
    (401305001065, 401305001065, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001066, 401305001066, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001067, 401305001067, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001068, 401305001068, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[0].sections[5]"  (PAV BHAJI)
    (401305001069, 401305001069, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001070, 401305001070, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001071, 401305001071, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001072, 401305001072, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001073, 401305001073, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001074, 401305001074, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001075, 401305001075, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001076, 401305001076, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001077, 401305001077, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001078, 401305001078, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001079, 401305001079, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001080, 401305001080, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001081, 401305001081, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001082, 401305001082, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001083, 401305001083, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001084, 401305001084, '1 Pc', 'per_piece', 1, 'pieces', 1, TRUE),
    (401305001085, 401305001085, '1 Pc', 'per_piece', 1, 'pieces', 1, TRUE),
    -- Source: JSON, "pages[0].sections[6]"  (KOLHAPURI KARAMAT / INDIAN STARTER)
    (401305001086, 401305001086, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001087, 401305001087, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001088, 401305001088, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001089, 401305001089, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001090, 401305001090, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001091, 401305001091, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001092, 401305001092, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001093, 401305001093, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001094, 401305001094, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001095, 401305001095, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001096, 401305001096, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[0].sections[7]"  (MAIN COURSE (PUNJABI DISHES))
    (401305001097, 401305001097, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001098, 401305001098, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001099, 401305001099, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001100, 401305001100, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001101, 401305001101, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001102, 401305001102, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001103, 401305001103, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001104, 401305001104, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001105, 401305001105, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001106, 401305001106, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001107, 401305001107, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001108, 401305001108, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001109, 401305001109, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001110, 401305001110, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001111, 401305001111, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001112, 401305001112, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001113, 401305001113, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001114, 401305001114, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001115, 401305001115, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001116, 401305001116, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001117, 401305001117, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001118, 401305001118, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001119, 401305001119, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001120, 401305001120, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001121, 401305001121, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001122, 401305001122, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001123, 401305001123, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001124, 401305001124, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001125, 401305001125, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001126, 401305001126, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001127, 401305001127, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001128, 401305001128, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001129, 401305001129, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001130, 401305001130, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001131, 401305001131, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001132, 401305001132, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001133, 401305001133, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001134, 401305001134, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001135, 401305001135, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001136, 401305001136, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001137, 401305001137, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001138, 401305001138, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001139, 401305001139, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001140, 401305001140, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001141, 401305001141, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001142, 401305001142, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[0].sections[8]"  (PANEER SPECIAL DISHES)
    (401305001143, 401305001143, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001144, 401305001144, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001145, 401305001145, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001146, 401305001146, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001147, 401305001147, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001148, 401305001148, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001149, 401305001149, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001150, 401305001150, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001151, 401305001151, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001152, 401305001152, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001153, 401305001153, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001154, 401305001154, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001155, 401305001155, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001156, 401305001156, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001157, 401305001157, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001158, 401305001158, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001159, 401305001159, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001160, 401305001160, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001161, 401305001161, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001162, 401305001162, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001163, 401305001163, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001164, 401305001164, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001165, 401305001165, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001166, 401305001166, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001167, 401305001167, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001168, 401305001168, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001169, 401305001169, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[0].sections[9]"  (MUSHROOM SPECIAL DISHES)
    (401305001170, 401305001170, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001171, 401305001171, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001172, 401305001172, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001173, 401305001173, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001174, 401305001174, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001175, 401305001175, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001176, 401305001176, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001177, 401305001177, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001178, 401305001178, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001179, 401305001179, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001180, 401305001180, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001181, 401305001181, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001182, 401305001182, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001183, 401305001183, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001184, 401305001184, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001185, 401305001185, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001186, 401305001186, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001187, 401305001187, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001188, 401305001188, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001189, 401305001189, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[0].sections[10]"  (CHOLE SPECIAL)
    (401305001190, 401305001190, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001191, 401305001191, '1 pc', 'per_piece', 1, 'pieces', 1, TRUE),
    -- Source: JSON, "pages[0].sections[11]"  (DAL KI DISHES)
    (401305001192, 401305001192, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001193, 401305001193, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001194, 401305001194, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001195, 401305001195, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001196, 401305001196, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001197, 401305001197, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001198, 401305001198, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001199, 401305001199, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[0].sections[12]"  (PAPAD)
    (401305001200, 401305001200, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001201, 401305001201, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001202, 401305001202, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001203, 401305001203, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001204, 401305001204, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001205, 401305001205, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[0].sections[13]"  (ROTI KI TOKRI)
    (401305001206, 401305001206, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001207, 401305001207, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001208, 401305001208, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001209, 401305001209, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001210, 401305001210, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001211, 401305001211, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001212, 401305001212, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001213, 401305001213, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001214, 401305001214, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001215, 401305001215, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001216, 401305001216, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001217, 401305001217, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001218, 401305001218, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001219, 401305001219, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001220, 401305001220, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001221, 401305001221, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001222, 401305001222, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001223, 401305001223, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001224, 401305001224, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001225, 401305001225, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001226, 401305001226, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[1].sections[0]"  (RICE)
    (401305001227, 401305001227, 'Half', 'fixed', NULL, NULL, 1, FALSE),
    (401305001228, 401305001227, 'Full', 'fixed', NULL, NULL, 2, TRUE),
    (401305001229, 401305001228, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001230, 401305001229, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001231, 401305001230, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001232, 401305001231, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001233, 401305001232, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001234, 401305001233, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001235, 401305001234, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001236, 401305001235, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001237, 401305001236, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001238, 401305001237, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001239, 401305001238, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001240, 401305001239, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001241, 401305001240, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001242, 401305001241, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001243, 401305001242, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001244, 401305001243, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001245, 401305001244, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001246, 401305001245, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001247, 401305001246, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001248, 401305001247, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001249, 401305001248, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001250, 401305001249, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[1].sections[1]"  (CHINESE SOUPS)
    (401305001251, 401305001250, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001252, 401305001251, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001253, 401305001252, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001254, 401305001253, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001255, 401305001254, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001256, 401305001255, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001257, 401305001256, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001258, 401305001257, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[1].sections[2]"  (CHINESE STARTERS & GRAVY)
    (401305001259, 401305001258, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001260, 401305001259, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001261, 401305001260, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001262, 401305001261, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001263, 401305001262, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001264, 401305001263, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001265, 401305001264, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001266, 401305001265, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001267, 401305001266, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001268, 401305001267, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001269, 401305001268, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001270, 401305001269, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001271, 401305001270, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001272, 401305001271, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001273, 401305001272, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[1].sections[3]"  (CHINESE STARTERS & GRAVY (CONTINUED))
    (401305001274, 401305001273, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001275, 401305001274, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001276, 401305001275, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001277, 401305001276, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001278, 401305001277, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001279, 401305001278, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001280, 401305001279, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001281, 401305001280, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001282, 401305001281, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[1].sections[4]"  (CHINESE RICE AND NOODLES)
    (401305001283, 401305001282, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001284, 401305001283, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001285, 401305001284, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001286, 401305001285, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001287, 401305001286, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001288, 401305001287, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001289, 401305001288, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001290, 401305001289, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001291, 401305001290, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001292, 401305001291, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001293, 401305001292, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001294, 401305001293, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001295, 401305001294, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001296, 401305001295, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001297, 401305001296, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001298, 401305001297, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001299, 401305001298, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001300, 401305001299, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001301, 401305001300, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[1].sections[5]"  (CHINESE TRIPLE RICE)
    (401305001302, 401305001301, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001303, 401305001302, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001304, 401305001303, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001305, 401305001304, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001306, 401305001305, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001307, 401305001306, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001308, 401305001307, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001309, 401305001308, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001310, 401305001309, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001311, 401305001310, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001312, 401305001311, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001313, 401305001312, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001314, 401305001313, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[1].sections[6]"  (SALAD (RUSSIAN SALAD, TOSS SALAD))
    (401305001315, 401305001314, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001316, 401305001315, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001317, 401305001316, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001318, 401305001317, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001319, 401305001318, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001320, 401305001319, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[1].sections[7]"  (COLD BEVERAGES)
    (401305001321, 401305001320, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001322, 401305001321, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001323, 401305001322, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001324, 401305001323, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001325, 401305001324, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001326, 401305001325, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001327, 401305001326, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[1].sections[8]"  (COLD DRINKS)
    (401305001328, 401305001327, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001329, 401305001328, '500 ml', 'fixed', 500, 'ml', 1, TRUE),
    (401305001330, 401305001329, '250 ml', 'fixed', 250, 'ml', 1, TRUE),
    (401305001331, 401305001330, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001332, 401305001331, '500 ml', 'fixed', 500, 'ml', 1, TRUE),
    (401305001333, 401305001332, '1 L', 'fixed', 1, 'l', 1, TRUE),
    -- Source: JSON, "pages[1].sections[9]"  (DESSERTS)
    (401305001334, 401305001333, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001335, 401305001334, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001336, 401305001335, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001337, 401305001336, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001338, 401305001337, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001339, 401305001338, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001340, 401305001339, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001341, 401305001340, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001342, 401305001341, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001343, 401305001342, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[1].sections[10]"  (MILK SHAKE)
    (401305001344, 401305001343, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001345, 401305001344, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001346, 401305001345, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001347, 401305001346, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001348, 401305001347, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001349, 401305001348, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001350, 401305001349, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001351, 401305001350, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001352, 401305001351, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001353, 401305001352, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[1].sections[11]"  (FALOODAS)
    (401305001354, 401305001353, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001355, 401305001354, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001356, 401305001355, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001357, 401305001356, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001358, 401305001357, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[1].sections[12]"  (FRESH JUICES)
    (401305001359, 401305001358, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001360, 401305001359, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001361, 401305001360, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    (401305001362, 401305001361, 'Regular', 'fixed', NULL, NULL, 1, TRUE),
    -- Source: JSON, "pages[1].sections[13]"  (RESTAURANT INFORMATION)
    (401305001363, 401305001362, 'Per Kg', 'per_kg', 1, 'kg', 1, TRUE),
    (401305001364, 401305001363, 'Per Kg', 'per_kg', 1, 'kg', 1, TRUE),
    (401305001365, 401305001364, 'Per Kg', 'per_kg', 1, 'kg', 1, TRUE);

-- ---------------------------------------------------------------------
-- Prices (INR). tax_inclusion_code = exclusive on every row because the menu prints
-- "*GOVT TAXES EXTRA AS APPLICABLE"; no rate / regime is stated, so tax_regime_code and
-- tax_rate stay NULL. Shared-price split lines carry the printed price on each dish.
-- ---------------------------------------------------------------------
INSERT INTO menu_item_price (
    price_id, variant_id, price_amount, tax_inclusion_code, effective_from, source_id, verification_status_code
) VALUES
    -- Source: JSON, "pages[0].sections[0]"  (HOT BEVERAGES)
    (401305001001, 401305001001, 30.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001002, 401305001002, 40.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001003, 401305001003, 40.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001004, 401305001004, 40.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[0].sections[1]"  (SOUTH INDIAN SNACKS)
    (401305001005, 401305001005, 70.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001006, 401305001006, 90.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001007, 401305001007, 90.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001008, 401305001008, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001009, 401305001009, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001010, 401305001010, 90.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001011, 401305001011, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001012, 401305001012, 95.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001013, 401305001013, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001014, 401305001014, 130.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001015, 401305001015, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001016, 401305001016, 100.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001017, 401305001017, 150.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001018, 401305001018, 150.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001019, 401305001019, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001020, 401305001020, 100.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001021, 401305001021, 220.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001022, 401305001022, 220.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001023, 401305001023, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001024, 401305001024, 50.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[0].sections[2]"  (DOSA SPECIALITIES)
    (401305001025, 401305001025, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001026, 401305001026, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001027, 401305001027, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001028, 401305001028, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001029, 401305001029, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001030, 401305001030, 130.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001031, 401305001031, 100.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001032, 401305001032, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001033, 401305001033, 130.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001034, 401305001034, 150.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001035, 401305001035, 100.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001036, 401305001036, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001037, 401305001037, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001038, 401305001038, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001039, 401305001039, 170.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001040, 401305001040, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001041, 401305001041, 100.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001042, 401305001042, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001043, 401305001043, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001044, 401305001044, 130.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001045, 401305001045, 160.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001046, 401305001046, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001047, 401305001047, 100.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001048, 401305001048, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001049, 401305001049, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001050, 401305001050, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001051, 401305001051, 170.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001052, 401305001052, 170.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[0].sections[3]"  (SANDWICHES)
    (401305001053, 401305001053, 30.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001054, 401305001054, 40.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001055, 401305001055, 70.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001056, 401305001056, 100.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001057, 401305001057, 100.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001058, 401305001058, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001059, 401305001059, 170.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'needs_review'),
    (401305001060, 401305001060, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001061, 401305001061, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001062, 401305001062, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001063, 401305001063, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001064, 401305001064, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[0].sections[4]"  (UPVAS SPECIAL)
    (401305001065, 401305001065, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001066, 401305001066, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001067, 401305001067, 130.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001068, 401305001068, 140.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[0].sections[5]"  (PAV BHAJI)
    (401305001069, 401305001069, 135.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001070, 401305001070, 155.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001071, 401305001071, 160.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001072, 401305001072, 145.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001073, 401305001073, 155.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001074, 401305001074, 155.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001075, 401305001075, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001076, 401305001076, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001077, 401305001077, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001078, 401305001078, 135.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001079, 401305001079, 135.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001080, 401305001080, 160.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001081, 401305001081, 160.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001082, 401305001082, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001083, 401305001083, 115.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001084, 401305001084, 15.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001085, 401305001085, 8.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[0].sections[6]"  (KOLHAPURI KARAMAT / INDIAN STARTER)
    (401305001086, 401305001086, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001087, 401305001087, 320.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001088, 401305001088, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001089, 401305001089, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001090, 401305001090, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001091, 401305001091, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001092, 401305001092, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001093, 401305001093, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001094, 401305001094, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001095, 401305001095, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001096, 401305001096, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[0].sections[7]"  (MAIN COURSE (PUNJABI DISHES))
    (401305001097, 401305001097, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001098, 401305001098, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001099, 401305001099, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001100, 401305001100, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001101, 401305001101, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001102, 401305001102, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001103, 401305001103, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001104, 401305001104, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001105, 401305001105, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001106, 401305001106, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001107, 401305001107, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001108, 401305001108, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001109, 401305001109, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001110, 401305001110, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001111, 401305001111, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001112, 401305001112, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001113, 401305001113, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001114, 401305001114, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001115, 401305001115, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001116, 401305001116, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001117, 401305001117, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001118, 401305001118, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001119, 401305001119, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001120, 401305001120, 210.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001121, 401305001121, 210.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001122, 401305001122, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001123, 401305001123, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001124, 401305001124, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001125, 401305001125, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001126, 401305001126, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001127, 401305001127, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001128, 401305001128, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001129, 401305001129, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001130, 401305001130, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001131, 401305001131, 220.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001132, 401305001132, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001133, 401305001133, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001134, 401305001134, 270.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001135, 401305001135, 270.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001136, 401305001136, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001137, 401305001137, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001138, 401305001138, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001139, 401305001139, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001140, 401305001140, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001141, 401305001141, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001142, 401305001142, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[0].sections[8]"  (PANEER SPECIAL DISHES)
    (401305001143, 401305001143, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001144, 401305001144, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001145, 401305001145, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001146, 401305001146, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001147, 401305001147, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001148, 401305001148, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001149, 401305001149, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001150, 401305001150, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001151, 401305001151, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001152, 401305001152, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001153, 401305001153, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001154, 401305001154, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001155, 401305001155, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001156, 401305001156, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001157, 401305001157, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001158, 401305001158, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001159, 401305001159, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001160, 401305001160, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001161, 401305001161, 280.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001162, 401305001162, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001163, 401305001163, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001164, 401305001164, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001165, 401305001165, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001166, 401305001166, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001167, 401305001167, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001168, 401305001168, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001169, 401305001169, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[0].sections[9]"  (MUSHROOM SPECIAL DISHES)
    (401305001170, 401305001170, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001171, 401305001171, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001172, 401305001172, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001173, 401305001173, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001174, 401305001174, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001175, 401305001175, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001176, 401305001176, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001177, 401305001177, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001178, 401305001178, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001179, 401305001179, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001180, 401305001180, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001181, 401305001181, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001182, 401305001182, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001183, 401305001183, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001184, 401305001184, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001185, 401305001185, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001186, 401305001186, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001187, 401305001187, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001188, 401305001188, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001189, 401305001189, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[0].sections[10]"  (CHOLE SPECIAL)
    (401305001190, 401305001190, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001191, 401305001191, 60.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[0].sections[11]"  (DAL KI DISHES)
    (401305001192, 401305001192, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001193, 401305001193, 130.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001194, 401305001194, 130.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001195, 401305001195, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001196, 401305001196, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001197, 401305001197, 140.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001198, 401305001198, 170.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001199, 401305001199, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[0].sections[12]"  (PAPAD)
    (401305001200, 401305001200, 30.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001201, 401305001201, 30.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001202, 401305001202, 50.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001203, 401305001203, 40.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001204, 401305001204, 40.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001205, 401305001205, 60.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[0].sections[13]"  (ROTI KI TOKRI)
    (401305001206, 401305001206, 15.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001207, 401305001207, 20.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001208, 401305001208, 20.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001209, 401305001209, 20.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001210, 401305001210, 30.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001211, 401305001211, 40.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001212, 401305001212, 50.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001213, 401305001213, 50.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001214, 401305001214, 60.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001215, 401305001215, 60.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001216, 401305001216, 40.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001217, 401305001217, 50.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001218, 401305001218, 40.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001219, 401305001219, 50.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001220, 401305001220, 100.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001221, 401305001221, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001222, 401305001222, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001223, 401305001223, 130.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001224, 401305001224, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001225, 401305001225, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001226, 401305001226, 100.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[0]"  (RICE)
    (401305001227, 401305001227, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001228, 401305001228, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001229, 401305001229, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001230, 401305001230, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001231, 401305001231, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001232, 401305001232, 190.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001233, 401305001233, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001234, 401305001234, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001235, 401305001235, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001236, 401305001236, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001237, 401305001237, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001238, 401305001238, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001239, 401305001239, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001240, 401305001240, 190.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'needs_review'),
    (401305001241, 401305001241, 160.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'needs_review'),
    (401305001242, 401305001242, 170.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001243, 401305001243, 170.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001244, 401305001244, 170.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001245, 401305001245, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001246, 401305001246, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001247, 401305001247, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001248, 401305001248, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001249, 401305001249, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001250, 401305001250, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[1]"  (CHINESE SOUPS)
    (401305001251, 401305001251, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001252, 401305001252, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001253, 401305001253, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001254, 401305001254, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001255, 401305001255, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001256, 401305001256, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001257, 401305001257, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001258, 401305001258, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[2]"  (CHINESE STARTERS & GRAVY)
    (401305001259, 401305001259, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001260, 401305001260, 130.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001261, 401305001261, 160.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001262, 401305001262, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001263, 401305001263, 190.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001264, 401305001264, 190.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001265, 401305001265, 190.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001266, 401305001266, 190.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001267, 401305001267, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001268, 401305001268, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001269, 401305001269, 180.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001270, 401305001270, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001271, 401305001271, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001272, 401305001272, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001273, 401305001273, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[3]"  (CHINESE STARTERS & GRAVY (CONTINUED))
    (401305001274, 401305001274, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001275, 401305001275, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001276, 401305001276, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001277, 401305001277, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001278, 401305001278, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001279, 401305001279, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001280, 401305001280, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001281, 401305001281, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001282, 401305001282, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[4]"  (CHINESE RICE AND NOODLES)
    (401305001283, 401305001283, 190.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001284, 401305001284, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001285, 401305001285, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001286, 401305001286, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001287, 401305001287, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001288, 401305001288, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001289, 401305001289, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001290, 401305001290, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001291, 401305001291, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001292, 401305001292, 210.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001293, 401305001293, 190.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001294, 401305001294, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001295, 401305001295, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001296, 401305001296, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001297, 401305001297, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001298, 401305001298, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001299, 401305001299, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001300, 401305001300, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001301, 401305001301, 230.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[5]"  (CHINESE TRIPLE RICE)
    (401305001302, 401305001302, 250.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001303, 401305001303, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001304, 401305001304, 240.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001305, 401305001305, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001306, 401305001306, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001307, 401305001307, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001308, 401305001308, 260.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001309, 401305001309, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001310, 401305001310, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001311, 401305001311, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001312, 401305001312, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001313, 401305001313, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001314, 401305001314, 300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[6]"  (SALAD (RUSSIAN SALAD, TOSS SALAD))
    (401305001315, 401305001315, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001316, 401305001316, 90.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001317, 401305001317, 70.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001318, 401305001318, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001319, 401305001319, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001320, 401305001320, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[7]"  (COLD BEVERAGES)
    (401305001321, 401305001321, 100.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001322, 401305001322, 50.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001323, 401305001323, 60.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001324, 401305001324, 30.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001325, 401305001325, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001326, 401305001326, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001327, 401305001327, 50.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[8]"  (COLD DRINKS)
    (401305001328, 401305001328, 135.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001329, 401305001329, 50.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001330, 401305001330, 25.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001331, 401305001331, 50.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001332, 401305001332, 15.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001333, 401305001333, 25.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[9]"  (DESSERTS)
    (401305001334, 401305001334, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001335, 401305001335, 150.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001336, 401305001336, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001337, 401305001337, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001338, 401305001338, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001339, 401305001339, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001340, 401305001340, 80.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001341, 401305001341, 50.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001342, 401305001342, 70.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001343, 401305001343, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[10]"  (MILK SHAKE)
    (401305001344, 401305001344, 130.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001345, 401305001345, 130.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001346, 401305001346, 130.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001347, 401305001347, 140.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001348, 401305001348, 140.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001349, 401305001349, 120.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001350, 401305001350, 100.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001351, 401305001351, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001352, 401305001352, 100.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001353, 401305001353, 150.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[11]"  (FALOODAS)
    (401305001354, 401305001354, 160.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001355, 401305001355, 160.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001356, 401305001356, 160.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001357, 401305001357, 160.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001358, 401305001358, 200.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[12]"  (FRESH JUICES)
    (401305001359, 401305001359, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001360, 401305001360, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001361, 401305001361, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001362, 401305001362, 110.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    -- Source: JSON, "pages[1].sections[13]"  (RESTAURANT INFORMATION)
    (401305001363, 401305001363, 1300.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001364, 401305001364, 1500.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified'),
    (401305001365, 401305001365, 1600.00, 'exclusive', (clock_timestamp() AT TIME ZONE 'UTC'), 401305001, 'unverified');

-- ---------------------------------------------------------------------
-- Provenance: menu_item_source (name/existence confidence) and menu_item_price_source (price confidence)
-- ---------------------------------------------------------------------
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code) VALUES
    -- Source: JSON, "pages[0].sections[0]"  (HOT BEVERAGES)
    (401305001001, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001002, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001003, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001004, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[0].sections[1]"  (SOUTH INDIAN SNACKS)
    (401305001005, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001006, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001007, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001008, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001009, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001010, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001011, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001012, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001013, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001014, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001015, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001016, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001017, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001018, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001019, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001020, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001021, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001022, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001023, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001024, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[0].sections[2]"  (DOSA SPECIALITIES)
    (401305001025, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001026, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001027, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001028, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001029, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001030, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001031, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001032, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001033, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001034, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001035, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001036, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001037, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001038, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001039, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001040, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001041, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001042, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001043, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001044, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001045, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001046, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001047, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001048, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001049, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001050, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001051, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001052, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[0].sections[3]"  (SANDWICHES)
    (401305001053, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001054, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001055, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001056, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001057, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001058, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001059, 401305001, 4013050010001, 0.90000, 'needs_review'),
    (401305001060, 401305001, 4013050010001, 0.90000, 'needs_review'),
    (401305001061, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001062, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001063, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001064, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[0].sections[4]"  (UPVAS SPECIAL)
    (401305001065, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001066, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001067, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001068, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[0].sections[5]"  (PAV BHAJI)
    (401305001069, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001070, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001071, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001072, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001073, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001074, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001075, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001076, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001077, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001078, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001079, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001080, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001081, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001082, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001083, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001084, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001085, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[0].sections[6]"  (KOLHAPURI KARAMAT / INDIAN STARTER)
    (401305001086, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001087, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001088, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001089, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001090, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001091, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001092, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001093, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001094, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001095, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001096, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[0].sections[7]"  (MAIN COURSE (PUNJABI DISHES))
    (401305001097, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001098, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001099, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001100, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001101, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001102, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001103, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001104, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001105, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001106, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001107, 401305001, 4013050010001, 0.90000, 'needs_review'),
    (401305001108, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001109, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001110, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001111, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001112, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001113, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001114, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001115, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001116, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001117, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001118, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001119, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001120, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001121, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001122, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001123, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001124, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001125, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001126, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001127, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001128, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001129, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001130, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001131, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001132, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001133, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001134, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001135, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001136, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001137, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001138, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001139, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001140, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001141, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001142, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[0].sections[8]"  (PANEER SPECIAL DISHES)
    (401305001143, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001144, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001145, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001146, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001147, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001148, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001149, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001150, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001151, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001152, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001153, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001154, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001155, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001156, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001157, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001158, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001159, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001160, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001161, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001162, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001163, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001164, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001165, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001166, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001167, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001168, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001169, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[0].sections[9]"  (MUSHROOM SPECIAL DISHES)
    (401305001170, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001171, 401305001, 4013050010001, 0.50000, 'needs_review'),
    (401305001172, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001173, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001174, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001175, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001176, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001177, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001178, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001179, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001180, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001181, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001182, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001183, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001184, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001185, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001186, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001187, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001188, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001189, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[0].sections[10]"  (CHOLE SPECIAL)
    (401305001190, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001191, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[0].sections[11]"  (DAL KI DISHES)
    (401305001192, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001193, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001194, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001195, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001196, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001197, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001198, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001199, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[0].sections[12]"  (PAPAD)
    (401305001200, 401305001, 4013050010001, 0.85000, 'unverified'),
    (401305001201, 401305001, 4013050010001, 0.85000, 'unverified'),
    (401305001202, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001203, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001204, 401305001, 4013050010001, 0.70000, 'needs_review'),
    (401305001205, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[0].sections[13]"  (ROTI KI TOKRI)
    (401305001206, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001207, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001208, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001209, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001210, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001211, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001212, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001213, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001214, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001215, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001216, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001217, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001218, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001219, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001220, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001221, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001222, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001223, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001224, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001225, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001226, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[0]"  (RICE)
    (401305001227, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001228, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001229, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001230, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001231, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001232, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001233, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001234, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001235, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001236, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001237, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001238, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001239, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001240, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001241, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001242, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001243, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001244, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001245, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001246, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001247, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001248, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001249, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[1]"  (CHINESE SOUPS)
    (401305001250, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001251, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001252, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001253, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001254, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001255, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001256, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001257, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[2]"  (CHINESE STARTERS & GRAVY)
    (401305001258, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001259, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001260, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001261, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001262, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001263, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001264, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001265, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001266, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001267, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001268, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001269, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001270, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001271, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001272, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[3]"  (CHINESE STARTERS & GRAVY (CONTINUED))
    (401305001273, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001274, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001275, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001276, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001277, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001278, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001279, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001280, 401305001, 4013050010001, 0.90000, 'unverified'),
    (401305001281, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[4]"  (CHINESE RICE AND NOODLES)
    (401305001282, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001283, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001284, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001285, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001286, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001287, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001288, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001289, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001290, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001291, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001292, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001293, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001294, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001295, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001296, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001297, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001298, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001299, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001300, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[5]"  (CHINESE TRIPLE RICE)
    (401305001301, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001302, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001303, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001304, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001305, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001306, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001307, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001308, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001309, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001310, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001311, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001312, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001313, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[6]"  (SALAD (RUSSIAN SALAD, TOSS SALAD))
    (401305001314, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001315, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001316, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001317, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001318, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001319, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[7]"  (COLD BEVERAGES)
    (401305001320, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001321, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001322, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001323, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001324, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001325, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001326, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[8]"  (COLD DRINKS)
    (401305001327, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001328, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001329, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001330, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001331, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001332, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[9]"  (DESSERTS)
    (401305001333, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001334, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001335, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001336, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001337, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001338, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001339, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001340, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001341, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001342, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[10]"  (MILK SHAKE)
    (401305001343, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001344, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001345, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001346, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001347, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001348, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001349, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001350, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001351, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001352, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[11]"  (FALOODAS)
    (401305001353, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001354, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001355, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001356, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001357, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[12]"  (FRESH JUICES)
    (401305001358, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001359, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001360, 401305001, 4013050010001, 0.95000, 'unverified'),
    (401305001361, 401305001, 4013050010001, 0.95000, 'unverified'),
    -- Source: JSON, "pages[1].sections[13]"  (RESTAURANT INFORMATION)
    (401305001362, 401305001, 4013050010001, 0.85000, 'unverified'),
    (401305001363, 401305001, 4013050010001, 0.85000, 'unverified'),
    (401305001364, 401305001, 4013050010001, 0.85000, 'unverified');

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence) VALUES
    -- Source: JSON, "pages[0].sections[0]"  (HOT BEVERAGES)
    (401305001001, 401305001, 4013050010001, 0.95000),
    (401305001002, 401305001, 4013050010001, 0.95000),
    (401305001003, 401305001, 4013050010001, 0.95000),
    (401305001004, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[0].sections[1]"  (SOUTH INDIAN SNACKS)
    (401305001005, 401305001, 4013050010001, 0.95000),
    (401305001006, 401305001, 4013050010001, 0.95000),
    (401305001007, 401305001, 4013050010001, 0.95000),
    (401305001008, 401305001, 4013050010001, 0.85000),
    (401305001009, 401305001, 4013050010001, 0.85000),
    (401305001010, 401305001, 4013050010001, 0.95000),
    (401305001011, 401305001, 4013050010001, 0.95000),
    (401305001012, 401305001, 4013050010001, 0.95000),
    (401305001013, 401305001, 4013050010001, 0.95000),
    (401305001014, 401305001, 4013050010001, 0.95000),
    (401305001015, 401305001, 4013050010001, 0.95000),
    (401305001016, 401305001, 4013050010001, 0.95000),
    (401305001017, 401305001, 4013050010001, 0.95000),
    (401305001018, 401305001, 4013050010001, 0.95000),
    (401305001019, 401305001, 4013050010001, 0.95000),
    (401305001020, 401305001, 4013050010001, 0.95000),
    (401305001021, 401305001, 4013050010001, 0.85000),
    (401305001022, 401305001, 4013050010001, 0.85000),
    (401305001023, 401305001, 4013050010001, 0.95000),
    (401305001024, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[0].sections[2]"  (DOSA SPECIALITIES)
    (401305001025, 401305001, 4013050010001, 0.95000),
    (401305001026, 401305001, 4013050010001, 0.95000),
    (401305001027, 401305001, 4013050010001, 0.95000),
    (401305001028, 401305001, 4013050010001, 0.95000),
    (401305001029, 401305001, 4013050010001, 0.95000),
    (401305001030, 401305001, 4013050010001, 0.95000),
    (401305001031, 401305001, 4013050010001, 0.95000),
    (401305001032, 401305001, 4013050010001, 0.95000),
    (401305001033, 401305001, 4013050010001, 0.95000),
    (401305001034, 401305001, 4013050010001, 0.95000),
    (401305001035, 401305001, 4013050010001, 0.95000),
    (401305001036, 401305001, 4013050010001, 0.85000),
    (401305001037, 401305001, 4013050010001, 0.85000),
    (401305001038, 401305001, 4013050010001, 0.95000),
    (401305001039, 401305001, 4013050010001, 0.95000),
    (401305001040, 401305001, 4013050010001, 0.95000),
    (401305001041, 401305001, 4013050010001, 0.95000),
    (401305001042, 401305001, 4013050010001, 0.95000),
    (401305001043, 401305001, 4013050010001, 0.95000),
    (401305001044, 401305001, 4013050010001, 0.95000),
    (401305001045, 401305001, 4013050010001, 0.95000),
    (401305001046, 401305001, 4013050010001, 0.95000),
    (401305001047, 401305001, 4013050010001, 0.95000),
    (401305001048, 401305001, 4013050010001, 0.95000),
    (401305001049, 401305001, 4013050010001, 0.85000),
    (401305001050, 401305001, 4013050010001, 0.85000),
    (401305001051, 401305001, 4013050010001, 0.95000),
    (401305001052, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[0].sections[3]"  (SANDWICHES)
    (401305001053, 401305001, 4013050010001, 0.95000),
    (401305001054, 401305001, 4013050010001, 0.95000),
    (401305001055, 401305001, 4013050010001, 0.95000),
    (401305001056, 401305001, 4013050010001, 0.95000),
    (401305001057, 401305001, 4013050010001, 0.95000),
    (401305001058, 401305001, 4013050010001, 0.95000),
    (401305001059, 401305001, 4013050010001, 0.60000),
    (401305001060, 401305001, 4013050010001, 0.95000),
    (401305001061, 401305001, 4013050010001, 0.95000),
    (401305001062, 401305001, 4013050010001, 0.95000),
    (401305001063, 401305001, 4013050010001, 0.95000),
    (401305001064, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[0].sections[4]"  (UPVAS SPECIAL)
    (401305001065, 401305001, 4013050010001, 0.95000),
    (401305001066, 401305001, 4013050010001, 0.95000),
    (401305001067, 401305001, 4013050010001, 0.95000),
    (401305001068, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[0].sections[5]"  (PAV BHAJI)
    (401305001069, 401305001, 4013050010001, 0.95000),
    (401305001070, 401305001, 4013050010001, 0.95000),
    (401305001071, 401305001, 4013050010001, 0.95000),
    (401305001072, 401305001, 4013050010001, 0.95000),
    (401305001073, 401305001, 4013050010001, 0.95000),
    (401305001074, 401305001, 4013050010001, 0.95000),
    (401305001075, 401305001, 4013050010001, 0.95000),
    (401305001076, 401305001, 4013050010001, 0.95000),
    (401305001077, 401305001, 4013050010001, 0.95000),
    (401305001078, 401305001, 4013050010001, 0.95000),
    (401305001079, 401305001, 4013050010001, 0.95000),
    (401305001080, 401305001, 4013050010001, 0.95000),
    (401305001081, 401305001, 4013050010001, 0.95000),
    (401305001082, 401305001, 4013050010001, 0.95000),
    (401305001083, 401305001, 4013050010001, 0.95000),
    (401305001084, 401305001, 4013050010001, 0.95000),
    (401305001085, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[0].sections[6]"  (KOLHAPURI KARAMAT / INDIAN STARTER)
    (401305001086, 401305001, 4013050010001, 0.95000),
    (401305001087, 401305001, 4013050010001, 0.95000),
    (401305001088, 401305001, 4013050010001, 0.95000),
    (401305001089, 401305001, 4013050010001, 0.95000),
    (401305001090, 401305001, 4013050010001, 0.95000),
    (401305001091, 401305001, 4013050010001, 0.95000),
    (401305001092, 401305001, 4013050010001, 0.95000),
    (401305001093, 401305001, 4013050010001, 0.95000),
    (401305001094, 401305001, 4013050010001, 0.95000),
    (401305001095, 401305001, 4013050010001, 0.95000),
    (401305001096, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[0].sections[7]"  (MAIN COURSE (PUNJABI DISHES))
    (401305001097, 401305001, 4013050010001, 0.85000),
    (401305001098, 401305001, 4013050010001, 0.85000),
    (401305001099, 401305001, 4013050010001, 0.85000),
    (401305001100, 401305001, 4013050010001, 0.85000),
    (401305001101, 401305001, 4013050010001, 0.85000),
    (401305001102, 401305001, 4013050010001, 0.85000),
    (401305001103, 401305001, 4013050010001, 0.95000),
    (401305001104, 401305001, 4013050010001, 0.85000),
    (401305001105, 401305001, 4013050010001, 0.85000),
    (401305001106, 401305001, 4013050010001, 0.85000),
    (401305001107, 401305001, 4013050010001, 0.85000),
    (401305001108, 401305001, 4013050010001, 0.85000),
    (401305001109, 401305001, 4013050010001, 0.85000),
    (401305001110, 401305001, 4013050010001, 0.85000),
    (401305001111, 401305001, 4013050010001, 0.85000),
    (401305001112, 401305001, 4013050010001, 0.95000),
    (401305001113, 401305001, 4013050010001, 0.85000),
    (401305001114, 401305001, 4013050010001, 0.85000),
    (401305001115, 401305001, 4013050010001, 0.95000),
    (401305001116, 401305001, 4013050010001, 0.85000),
    (401305001117, 401305001, 4013050010001, 0.85000),
    (401305001118, 401305001, 4013050010001, 0.85000),
    (401305001119, 401305001, 4013050010001, 0.85000),
    (401305001120, 401305001, 4013050010001, 0.85000),
    (401305001121, 401305001, 4013050010001, 0.85000),
    (401305001122, 401305001, 4013050010001, 0.95000),
    (401305001123, 401305001, 4013050010001, 0.95000),
    (401305001124, 401305001, 4013050010001, 0.95000),
    (401305001125, 401305001, 4013050010001, 0.85000),
    (401305001126, 401305001, 4013050010001, 0.85000),
    (401305001127, 401305001, 4013050010001, 0.95000),
    (401305001128, 401305001, 4013050010001, 0.85000),
    (401305001129, 401305001, 4013050010001, 0.85000),
    (401305001130, 401305001, 4013050010001, 0.95000),
    (401305001131, 401305001, 4013050010001, 0.95000),
    (401305001132, 401305001, 4013050010001, 0.95000),
    (401305001133, 401305001, 4013050010001, 0.95000),
    (401305001134, 401305001, 4013050010001, 0.85000),
    (401305001135, 401305001, 4013050010001, 0.85000),
    (401305001136, 401305001, 4013050010001, 0.95000),
    (401305001137, 401305001, 4013050010001, 0.95000),
    (401305001138, 401305001, 4013050010001, 0.95000),
    (401305001139, 401305001, 4013050010001, 0.95000),
    (401305001140, 401305001, 4013050010001, 0.95000),
    (401305001141, 401305001, 4013050010001, 0.95000),
    (401305001142, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[0].sections[8]"  (PANEER SPECIAL DISHES)
    (401305001143, 401305001, 4013050010001, 0.95000),
    (401305001144, 401305001, 4013050010001, 0.85000),
    (401305001145, 401305001, 4013050010001, 0.85000),
    (401305001146, 401305001, 4013050010001, 0.95000),
    (401305001147, 401305001, 4013050010001, 0.95000),
    (401305001148, 401305001, 4013050010001, 0.80000),
    (401305001149, 401305001, 4013050010001, 0.80000),
    (401305001150, 401305001, 4013050010001, 0.85000),
    (401305001151, 401305001, 4013050010001, 0.85000),
    (401305001152, 401305001, 4013050010001, 0.85000),
    (401305001153, 401305001, 4013050010001, 0.85000),
    (401305001154, 401305001, 4013050010001, 0.95000),
    (401305001155, 401305001, 4013050010001, 0.95000),
    (401305001156, 401305001, 4013050010001, 0.95000),
    (401305001157, 401305001, 4013050010001, 0.95000),
    (401305001158, 401305001, 4013050010001, 0.95000),
    (401305001159, 401305001, 4013050010001, 0.95000),
    (401305001160, 401305001, 4013050010001, 0.95000),
    (401305001161, 401305001, 4013050010001, 0.95000),
    (401305001162, 401305001, 4013050010001, 0.80000),
    (401305001163, 401305001, 4013050010001, 0.80000),
    (401305001164, 401305001, 4013050010001, 0.80000),
    (401305001165, 401305001, 4013050010001, 0.95000),
    (401305001166, 401305001, 4013050010001, 0.95000),
    (401305001167, 401305001, 4013050010001, 0.95000),
    (401305001168, 401305001, 4013050010001, 0.95000),
    (401305001169, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[0].sections[9]"  (MUSHROOM SPECIAL DISHES)
    (401305001170, 401305001, 4013050010001, 0.95000),
    (401305001171, 401305001, 4013050010001, 0.95000),
    (401305001172, 401305001, 4013050010001, 0.95000),
    (401305001173, 401305001, 4013050010001, 0.95000),
    (401305001174, 401305001, 4013050010001, 0.80000),
    (401305001175, 401305001, 4013050010001, 0.80000),
    (401305001176, 401305001, 4013050010001, 0.95000),
    (401305001177, 401305001, 4013050010001, 0.95000),
    (401305001178, 401305001, 4013050010001, 0.95000),
    (401305001179, 401305001, 4013050010001, 0.95000),
    (401305001180, 401305001, 4013050010001, 0.95000),
    (401305001181, 401305001, 4013050010001, 0.95000),
    (401305001182, 401305001, 4013050010001, 0.80000),
    (401305001183, 401305001, 4013050010001, 0.80000),
    (401305001184, 401305001, 4013050010001, 0.95000),
    (401305001185, 401305001, 4013050010001, 0.95000),
    (401305001186, 401305001, 4013050010001, 0.80000),
    (401305001187, 401305001, 4013050010001, 0.80000),
    (401305001188, 401305001, 4013050010001, 0.80000),
    (401305001189, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[0].sections[10]"  (CHOLE SPECIAL)
    (401305001190, 401305001, 4013050010001, 0.95000),
    (401305001191, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[0].sections[11]"  (DAL KI DISHES)
    (401305001192, 401305001, 4013050010001, 0.95000),
    (401305001193, 401305001, 4013050010001, 0.85000),
    (401305001194, 401305001, 4013050010001, 0.85000),
    (401305001195, 401305001, 4013050010001, 0.85000),
    (401305001196, 401305001, 4013050010001, 0.85000),
    (401305001197, 401305001, 4013050010001, 0.95000),
    (401305001198, 401305001, 4013050010001, 0.95000),
    (401305001199, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[0].sections[12]"  (PAPAD)
    (401305001200, 401305001, 4013050010001, 0.85000),
    (401305001201, 401305001, 4013050010001, 0.85000),
    (401305001202, 401305001, 4013050010001, 0.95000),
    (401305001203, 401305001, 4013050010001, 0.80000),
    (401305001204, 401305001, 4013050010001, 0.80000),
    (401305001205, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[0].sections[13]"  (ROTI KI TOKRI)
    (401305001206, 401305001, 4013050010001, 0.95000),
    (401305001207, 401305001, 4013050010001, 0.95000),
    (401305001208, 401305001, 4013050010001, 0.95000),
    (401305001209, 401305001, 4013050010001, 0.95000),
    (401305001210, 401305001, 4013050010001, 0.95000),
    (401305001211, 401305001, 4013050010001, 0.95000),
    (401305001212, 401305001, 4013050010001, 0.85000),
    (401305001213, 401305001, 4013050010001, 0.85000),
    (401305001214, 401305001, 4013050010001, 0.85000),
    (401305001215, 401305001, 4013050010001, 0.85000),
    (401305001216, 401305001, 4013050010001, 0.95000),
    (401305001217, 401305001, 4013050010001, 0.95000),
    (401305001218, 401305001, 4013050010001, 0.95000),
    (401305001219, 401305001, 4013050010001, 0.95000),
    (401305001220, 401305001, 4013050010001, 0.95000),
    (401305001221, 401305001, 4013050010001, 0.95000),
    (401305001222, 401305001, 4013050010001, 0.95000),
    (401305001223, 401305001, 4013050010001, 0.95000),
    (401305001224, 401305001, 4013050010001, 0.95000),
    (401305001225, 401305001, 4013050010001, 0.95000),
    (401305001226, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[0]"  (RICE)
    (401305001227, 401305001, 4013050010001, 0.95000),
    (401305001228, 401305001, 4013050010001, 0.95000),
    (401305001229, 401305001, 4013050010001, 0.95000),
    (401305001230, 401305001, 4013050010001, 0.95000),
    (401305001231, 401305001, 4013050010001, 0.95000),
    (401305001232, 401305001, 4013050010001, 0.95000),
    (401305001233, 401305001, 4013050010001, 0.95000),
    (401305001234, 401305001, 4013050010001, 0.95000),
    (401305001235, 401305001, 4013050010001, 0.95000),
    (401305001236, 401305001, 4013050010001, 0.95000),
    (401305001237, 401305001, 4013050010001, 0.95000),
    (401305001238, 401305001, 4013050010001, 0.95000),
    (401305001239, 401305001, 4013050010001, 0.95000),
    (401305001240, 401305001, 4013050010001, 0.65000),
    (401305001241, 401305001, 4013050010001, 0.65000),
    (401305001242, 401305001, 4013050010001, 0.95000),
    (401305001243, 401305001, 4013050010001, 0.95000),
    (401305001244, 401305001, 4013050010001, 0.95000),
    (401305001245, 401305001, 4013050010001, 0.95000),
    (401305001246, 401305001, 4013050010001, 0.95000),
    (401305001247, 401305001, 4013050010001, 0.95000),
    (401305001248, 401305001, 4013050010001, 0.95000),
    (401305001249, 401305001, 4013050010001, 0.95000),
    (401305001250, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[1]"  (CHINESE SOUPS)
    (401305001251, 401305001, 4013050010001, 0.85000),
    (401305001252, 401305001, 4013050010001, 0.85000),
    (401305001253, 401305001, 4013050010001, 0.95000),
    (401305001254, 401305001, 4013050010001, 0.95000),
    (401305001255, 401305001, 4013050010001, 0.95000),
    (401305001256, 401305001, 4013050010001, 0.95000),
    (401305001257, 401305001, 4013050010001, 0.95000),
    (401305001258, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[2]"  (CHINESE STARTERS & GRAVY)
    (401305001259, 401305001, 4013050010001, 0.95000),
    (401305001260, 401305001, 4013050010001, 0.95000),
    (401305001261, 401305001, 4013050010001, 0.95000),
    (401305001262, 401305001, 4013050010001, 0.95000),
    (401305001263, 401305001, 4013050010001, 0.95000),
    (401305001264, 401305001, 4013050010001, 0.95000),
    (401305001265, 401305001, 4013050010001, 0.95000),
    (401305001266, 401305001, 4013050010001, 0.95000),
    (401305001267, 401305001, 4013050010001, 0.95000),
    (401305001268, 401305001, 4013050010001, 0.95000),
    (401305001269, 401305001, 4013050010001, 0.95000),
    (401305001270, 401305001, 4013050010001, 0.95000),
    (401305001271, 401305001, 4013050010001, 0.95000),
    (401305001272, 401305001, 4013050010001, 0.95000),
    (401305001273, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[3]"  (CHINESE STARTERS & GRAVY (CONTINUED))
    (401305001274, 401305001, 4013050010001, 0.95000),
    (401305001275, 401305001, 4013050010001, 0.95000),
    (401305001276, 401305001, 4013050010001, 0.95000),
    (401305001277, 401305001, 4013050010001, 0.95000),
    (401305001278, 401305001, 4013050010001, 0.95000),
    (401305001279, 401305001, 4013050010001, 0.95000),
    (401305001280, 401305001, 4013050010001, 0.85000),
    (401305001281, 401305001, 4013050010001, 0.85000),
    (401305001282, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[4]"  (CHINESE RICE AND NOODLES)
    (401305001283, 401305001, 4013050010001, 0.95000),
    (401305001284, 401305001, 4013050010001, 0.95000),
    (401305001285, 401305001, 4013050010001, 0.95000),
    (401305001286, 401305001, 4013050010001, 0.95000),
    (401305001287, 401305001, 4013050010001, 0.95000),
    (401305001288, 401305001, 4013050010001, 0.95000),
    (401305001289, 401305001, 4013050010001, 0.95000),
    (401305001290, 401305001, 4013050010001, 0.95000),
    (401305001291, 401305001, 4013050010001, 0.95000),
    (401305001292, 401305001, 4013050010001, 0.95000),
    (401305001293, 401305001, 4013050010001, 0.95000),
    (401305001294, 401305001, 4013050010001, 0.95000),
    (401305001295, 401305001, 4013050010001, 0.95000),
    (401305001296, 401305001, 4013050010001, 0.95000),
    (401305001297, 401305001, 4013050010001, 0.95000),
    (401305001298, 401305001, 4013050010001, 0.95000),
    (401305001299, 401305001, 4013050010001, 0.95000),
    (401305001300, 401305001, 4013050010001, 0.95000),
    (401305001301, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[5]"  (CHINESE TRIPLE RICE)
    (401305001302, 401305001, 4013050010001, 0.95000),
    (401305001303, 401305001, 4013050010001, 0.95000),
    (401305001304, 401305001, 4013050010001, 0.95000),
    (401305001305, 401305001, 4013050010001, 0.95000),
    (401305001306, 401305001, 4013050010001, 0.95000),
    (401305001307, 401305001, 4013050010001, 0.95000),
    (401305001308, 401305001, 4013050010001, 0.95000),
    (401305001309, 401305001, 4013050010001, 0.95000),
    (401305001310, 401305001, 4013050010001, 0.95000),
    (401305001311, 401305001, 4013050010001, 0.95000),
    (401305001312, 401305001, 4013050010001, 0.95000),
    (401305001313, 401305001, 4013050010001, 0.95000),
    (401305001314, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[6]"  (SALAD (RUSSIAN SALAD, TOSS SALAD))
    (401305001315, 401305001, 4013050010001, 0.95000),
    (401305001316, 401305001, 4013050010001, 0.95000),
    (401305001317, 401305001, 4013050010001, 0.95000),
    (401305001318, 401305001, 4013050010001, 0.95000),
    (401305001319, 401305001, 4013050010001, 0.95000),
    (401305001320, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[7]"  (COLD BEVERAGES)
    (401305001321, 401305001, 4013050010001, 0.95000),
    (401305001322, 401305001, 4013050010001, 0.95000),
    (401305001323, 401305001, 4013050010001, 0.95000),
    (401305001324, 401305001, 4013050010001, 0.95000),
    (401305001325, 401305001, 4013050010001, 0.95000),
    (401305001326, 401305001, 4013050010001, 0.95000),
    (401305001327, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[8]"  (COLD DRINKS)
    (401305001328, 401305001, 4013050010001, 0.95000),
    (401305001329, 401305001, 4013050010001, 0.95000),
    (401305001330, 401305001, 4013050010001, 0.95000),
    (401305001331, 401305001, 4013050010001, 0.95000),
    (401305001332, 401305001, 4013050010001, 0.95000),
    (401305001333, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[9]"  (DESSERTS)
    (401305001334, 401305001, 4013050010001, 0.95000),
    (401305001335, 401305001, 4013050010001, 0.95000),
    (401305001336, 401305001, 4013050010001, 0.95000),
    (401305001337, 401305001, 4013050010001, 0.95000),
    (401305001338, 401305001, 4013050010001, 0.95000),
    (401305001339, 401305001, 4013050010001, 0.95000),
    (401305001340, 401305001, 4013050010001, 0.95000),
    (401305001341, 401305001, 4013050010001, 0.95000),
    (401305001342, 401305001, 4013050010001, 0.95000),
    (401305001343, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[10]"  (MILK SHAKE)
    (401305001344, 401305001, 4013050010001, 0.95000),
    (401305001345, 401305001, 4013050010001, 0.95000),
    (401305001346, 401305001, 4013050010001, 0.95000),
    (401305001347, 401305001, 4013050010001, 0.95000),
    (401305001348, 401305001, 4013050010001, 0.95000),
    (401305001349, 401305001, 4013050010001, 0.95000),
    (401305001350, 401305001, 4013050010001, 0.95000),
    (401305001351, 401305001, 4013050010001, 0.95000),
    (401305001352, 401305001, 4013050010001, 0.95000),
    (401305001353, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[11]"  (FALOODAS)
    (401305001354, 401305001, 4013050010001, 0.95000),
    (401305001355, 401305001, 4013050010001, 0.95000),
    (401305001356, 401305001, 4013050010001, 0.95000),
    (401305001357, 401305001, 4013050010001, 0.95000),
    (401305001358, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[12]"  (FRESH JUICES)
    (401305001359, 401305001, 4013050010001, 0.95000),
    (401305001360, 401305001, 4013050010001, 0.95000),
    (401305001361, 401305001, 4013050010001, 0.95000),
    (401305001362, 401305001, 4013050010001, 0.95000),
    -- Source: JSON, "pages[1].sections[13]"  (RESTAURANT INFORMATION)
    (401305001363, 401305001, 4013050010001, 0.90000),
    (401305001364, 401305001, 4013050010001, 0.90000),
    (401305001365, 401305001, 4013050010001, 0.90000);

-- ---------------------------------------------------------------------
-- Add-ons printed as section notes:
--   pages[0].sections[2] DOSA SPECIALITIES : "(Add Butter 20/- | Add Cheese or Paneer 30/-)"
--   pages[1].sections[10] MILK SHAKE       : "WITH ICE CREAM EXTRA CHARGE 50/-"
-- Scope assumption: a section note applies to every item in that section (the section
-- DOSA SPECIALITIES also holds the uttappas). "Cold Coffee with Ice Cream" is excluded
-- from the ice-cream add-on because it already includes it. "Cheese or Paneer" is kept
-- as ONE option exactly as printed.
-- ---------------------------------------------------------------------
INSERT INTO addon_group (addon_group_id, restaurant_id, name, selection_type, is_required) VALUES
    (4013050010001, 401305001, 'Dosa Add-ons', 'multiple', FALSE),
    (4013050010002, 401305001, 'Milk Shake Add-ons', 'single', FALSE);

INSERT INTO addon_option (addon_option_id, addon_group_id, name, extra_price) VALUES
    (4013050010001, 4013050010001, 'Add Butter', 20.00),
    (4013050010002, 4013050010001, 'Add Cheese or Paneer', 30.00),
    (4013050010003, 4013050010002, 'With Ice Cream', 50.00);

INSERT INTO menu_item_addon_group (menu_item_id, addon_group_id) VALUES
    (401305001025, 4013050010001),
    (401305001026, 4013050010001),
    (401305001027, 4013050010001),
    (401305001028, 4013050010001),
    (401305001029, 4013050010001),
    (401305001030, 4013050010001),
    (401305001031, 4013050010001),
    (401305001032, 4013050010001),
    (401305001033, 4013050010001),
    (401305001034, 4013050010001),
    (401305001035, 4013050010001),
    (401305001036, 4013050010001),
    (401305001037, 4013050010001),
    (401305001038, 4013050010001),
    (401305001039, 4013050010001),
    (401305001040, 4013050010001),
    (401305001041, 4013050010001),
    (401305001042, 4013050010001),
    (401305001043, 4013050010001),
    (401305001044, 4013050010001),
    (401305001045, 4013050010001),
    (401305001046, 4013050010001),
    (401305001047, 4013050010001),
    (401305001048, 4013050010001),
    (401305001049, 4013050010001),
    (401305001050, 4013050010001),
    (401305001051, 4013050010001),
    (401305001052, 4013050010001),
    (401305001343, 4013050010002),
    (401305001344, 4013050010002),
    (401305001345, 4013050010002),
    (401305001346, 4013050010002),
    (401305001347, 4013050010002),
    (401305001348, 4013050010002),
    (401305001349, 4013050010002),
    (401305001350, 4013050010002),
    (401305001351, 4013050010002);

-- ---------------------------------------------------------------------
-- Board mappings (menu_board_category has no ID column of its own)
-- ---------------------------------------------------------------------
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence) VALUES
    (401305001, 401305001001, 401305001001, 1),
    (401305001, 401305001001, 401305001002, 2),
    (401305001, 401305001001, 401305001003, 3),
    (401305001, 401305001001, 401305001004, 4),
    (401305001, 401305001001, 401305001005, 5),
    (401305001, 401305001001, 401305001006, 6),
    (401305001, 401305001001, 401305001007, 7),
    (401305001, 401305001001, 401305001008, 8),
    (401305001, 401305001001, 401305001009, 9),
    (401305001, 401305001001, 401305001010, 10),
    (401305001, 401305001001, 401305001011, 11),
    (401305001, 401305001001, 401305001012, 12),
    (401305001, 401305001001, 401305001013, 13),
    (401305001, 401305001001, 401305001014, 14),
    (401305001, 401305001001, 401305001015, 15),
    (401305001, 401305001001, 401305001016, 16),
    (401305001, 401305001001, 401305001017, 17),
    (401305001, 401305001001, 401305001018, 18),
    (401305001, 401305001001, 401305001019, 19),
    (401305001, 401305001001, 401305001020, 20),
    (401305001, 401305001001, 401305001021, 21),
    (401305001, 401305001001, 401305001022, 22),
    (401305001, 401305001001, 401305001023, 23),
    (401305001, 401305001001, 401305001024, 24),
    (401305001, 401305001001, 401305001025, 25),
    (401305001, 401305001001, 401305001026, 26);

INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence) VALUES
    -- Source: JSON, "pages[0].sections[0]"  (HOT BEVERAGES)
    (401305001001, 401305001, 401305001001, 401305001001, 401305001001, 1),
    (401305001002, 401305001, 401305001001, 401305001002, 401305001001, 2),
    (401305001003, 401305001, 401305001001, 401305001003, 401305001001, 3),
    (401305001004, 401305001, 401305001001, 401305001004, 401305001001, 4),
    -- Source: JSON, "pages[0].sections[1]"  (SOUTH INDIAN SNACKS)
    (401305001005, 401305001, 401305001001, 401305001005, 401305001002, 5),
    (401305001006, 401305001, 401305001001, 401305001006, 401305001002, 6),
    (401305001007, 401305001, 401305001001, 401305001007, 401305001002, 7),
    (401305001008, 401305001, 401305001001, 401305001008, 401305001002, 8),
    (401305001009, 401305001, 401305001001, 401305001009, 401305001002, 9),
    (401305001010, 401305001, 401305001001, 401305001010, 401305001002, 10),
    (401305001011, 401305001, 401305001001, 401305001011, 401305001002, 11),
    (401305001012, 401305001, 401305001001, 401305001012, 401305001002, 12),
    (401305001013, 401305001, 401305001001, 401305001013, 401305001002, 13),
    (401305001014, 401305001, 401305001001, 401305001014, 401305001002, 14),
    (401305001015, 401305001, 401305001001, 401305001015, 401305001002, 15),
    (401305001016, 401305001, 401305001001, 401305001016, 401305001002, 16),
    (401305001017, 401305001, 401305001001, 401305001017, 401305001002, 17),
    (401305001018, 401305001, 401305001001, 401305001018, 401305001002, 18),
    (401305001019, 401305001, 401305001001, 401305001019, 401305001002, 19),
    (401305001020, 401305001, 401305001001, 401305001020, 401305001002, 20),
    (401305001021, 401305001, 401305001001, 401305001021, 401305001002, 21),
    (401305001022, 401305001, 401305001001, 401305001022, 401305001002, 22),
    (401305001023, 401305001, 401305001001, 401305001023, 401305001002, 23),
    (401305001024, 401305001, 401305001001, 401305001024, 401305001002, 24),
    -- Source: JSON, "pages[0].sections[2]"  (DOSA SPECIALITIES)
    (401305001025, 401305001, 401305001001, 401305001025, 401305001003, 25),
    (401305001026, 401305001, 401305001001, 401305001026, 401305001003, 26),
    (401305001027, 401305001, 401305001001, 401305001027, 401305001003, 27),
    (401305001028, 401305001, 401305001001, 401305001028, 401305001003, 28),
    (401305001029, 401305001, 401305001001, 401305001029, 401305001003, 29),
    (401305001030, 401305001, 401305001001, 401305001030, 401305001003, 30),
    (401305001031, 401305001, 401305001001, 401305001031, 401305001003, 31),
    (401305001032, 401305001, 401305001001, 401305001032, 401305001003, 32),
    (401305001033, 401305001, 401305001001, 401305001033, 401305001003, 33),
    (401305001034, 401305001, 401305001001, 401305001034, 401305001003, 34),
    (401305001035, 401305001, 401305001001, 401305001035, 401305001003, 35),
    (401305001036, 401305001, 401305001001, 401305001036, 401305001003, 36),
    (401305001037, 401305001, 401305001001, 401305001037, 401305001003, 37),
    (401305001038, 401305001, 401305001001, 401305001038, 401305001003, 38),
    (401305001039, 401305001, 401305001001, 401305001039, 401305001003, 39),
    (401305001040, 401305001, 401305001001, 401305001040, 401305001003, 40),
    (401305001041, 401305001, 401305001001, 401305001041, 401305001003, 41),
    (401305001042, 401305001, 401305001001, 401305001042, 401305001003, 42),
    (401305001043, 401305001, 401305001001, 401305001043, 401305001003, 43),
    (401305001044, 401305001, 401305001001, 401305001044, 401305001003, 44),
    (401305001045, 401305001, 401305001001, 401305001045, 401305001003, 45),
    (401305001046, 401305001, 401305001001, 401305001046, 401305001003, 46),
    (401305001047, 401305001, 401305001001, 401305001047, 401305001003, 47),
    (401305001048, 401305001, 401305001001, 401305001048, 401305001003, 48),
    (401305001049, 401305001, 401305001001, 401305001049, 401305001003, 49),
    (401305001050, 401305001, 401305001001, 401305001050, 401305001003, 50),
    (401305001051, 401305001, 401305001001, 401305001051, 401305001003, 51),
    (401305001052, 401305001, 401305001001, 401305001052, 401305001003, 52),
    -- Source: JSON, "pages[0].sections[3]"  (SANDWICHES)
    (401305001053, 401305001, 401305001001, 401305001053, 401305001004, 53),
    (401305001054, 401305001, 401305001001, 401305001054, 401305001004, 54),
    (401305001055, 401305001, 401305001001, 401305001055, 401305001004, 55),
    (401305001056, 401305001, 401305001001, 401305001056, 401305001004, 56),
    (401305001057, 401305001, 401305001001, 401305001057, 401305001004, 57),
    (401305001058, 401305001, 401305001001, 401305001058, 401305001004, 58),
    (401305001059, 401305001, 401305001001, 401305001059, 401305001004, 59),
    (401305001060, 401305001, 401305001001, 401305001060, 401305001004, 60),
    (401305001061, 401305001, 401305001001, 401305001061, 401305001004, 61),
    (401305001062, 401305001, 401305001001, 401305001062, 401305001004, 62),
    (401305001063, 401305001, 401305001001, 401305001063, 401305001004, 63),
    (401305001064, 401305001, 401305001001, 401305001064, 401305001004, 64),
    -- Source: JSON, "pages[0].sections[4]"  (UPVAS SPECIAL)
    (401305001065, 401305001, 401305001001, 401305001065, 401305001005, 65),
    (401305001066, 401305001, 401305001001, 401305001066, 401305001005, 66),
    (401305001067, 401305001, 401305001001, 401305001067, 401305001005, 67),
    (401305001068, 401305001, 401305001001, 401305001068, 401305001005, 68),
    -- Source: JSON, "pages[0].sections[5]"  (PAV BHAJI)
    (401305001069, 401305001, 401305001001, 401305001069, 401305001006, 69),
    (401305001070, 401305001, 401305001001, 401305001070, 401305001006, 70),
    (401305001071, 401305001, 401305001001, 401305001071, 401305001006, 71),
    (401305001072, 401305001, 401305001001, 401305001072, 401305001006, 72),
    (401305001073, 401305001, 401305001001, 401305001073, 401305001006, 73),
    (401305001074, 401305001, 401305001001, 401305001074, 401305001006, 74),
    (401305001075, 401305001, 401305001001, 401305001075, 401305001006, 75),
    (401305001076, 401305001, 401305001001, 401305001076, 401305001006, 76),
    (401305001077, 401305001, 401305001001, 401305001077, 401305001006, 77),
    (401305001078, 401305001, 401305001001, 401305001078, 401305001006, 78),
    (401305001079, 401305001, 401305001001, 401305001079, 401305001006, 79),
    (401305001080, 401305001, 401305001001, 401305001080, 401305001006, 80),
    (401305001081, 401305001, 401305001001, 401305001081, 401305001006, 81),
    (401305001082, 401305001, 401305001001, 401305001082, 401305001006, 82),
    (401305001083, 401305001, 401305001001, 401305001083, 401305001006, 83),
    (401305001084, 401305001, 401305001001, 401305001084, 401305001006, 84),
    (401305001085, 401305001, 401305001001, 401305001085, 401305001006, 85),
    -- Source: JSON, "pages[0].sections[6]"  (KOLHAPURI KARAMAT / INDIAN STARTER)
    (401305001086, 401305001, 401305001001, 401305001086, 401305001007, 86),
    (401305001087, 401305001, 401305001001, 401305001087, 401305001007, 87),
    (401305001088, 401305001, 401305001001, 401305001088, 401305001007, 88),
    (401305001089, 401305001, 401305001001, 401305001089, 401305001007, 89),
    (401305001090, 401305001, 401305001001, 401305001090, 401305001007, 90),
    (401305001091, 401305001, 401305001001, 401305001091, 401305001007, 91),
    (401305001092, 401305001, 401305001001, 401305001092, 401305001007, 92),
    (401305001093, 401305001, 401305001001, 401305001093, 401305001007, 93),
    (401305001094, 401305001, 401305001001, 401305001094, 401305001007, 94),
    (401305001095, 401305001, 401305001001, 401305001095, 401305001007, 95),
    (401305001096, 401305001, 401305001001, 401305001096, 401305001007, 96),
    -- Source: JSON, "pages[0].sections[7]"  (MAIN COURSE (PUNJABI DISHES))
    (401305001097, 401305001, 401305001001, 401305001097, 401305001008, 97),
    (401305001098, 401305001, 401305001001, 401305001098, 401305001008, 98),
    (401305001099, 401305001, 401305001001, 401305001099, 401305001008, 99),
    (401305001100, 401305001, 401305001001, 401305001100, 401305001008, 100),
    (401305001101, 401305001, 401305001001, 401305001101, 401305001008, 101),
    (401305001102, 401305001, 401305001001, 401305001102, 401305001008, 102),
    (401305001103, 401305001, 401305001001, 401305001103, 401305001008, 103),
    (401305001104, 401305001, 401305001001, 401305001104, 401305001008, 104),
    (401305001105, 401305001, 401305001001, 401305001105, 401305001008, 105),
    (401305001106, 401305001, 401305001001, 401305001106, 401305001008, 106),
    (401305001107, 401305001, 401305001001, 401305001107, 401305001008, 107),
    (401305001108, 401305001, 401305001001, 401305001108, 401305001008, 108),
    (401305001109, 401305001, 401305001001, 401305001109, 401305001008, 109),
    (401305001110, 401305001, 401305001001, 401305001110, 401305001008, 110),
    (401305001111, 401305001, 401305001001, 401305001111, 401305001008, 111),
    (401305001112, 401305001, 401305001001, 401305001112, 401305001008, 112),
    (401305001113, 401305001, 401305001001, 401305001113, 401305001008, 113),
    (401305001114, 401305001, 401305001001, 401305001114, 401305001008, 114),
    (401305001115, 401305001, 401305001001, 401305001115, 401305001008, 115),
    (401305001116, 401305001, 401305001001, 401305001116, 401305001008, 116),
    (401305001117, 401305001, 401305001001, 401305001117, 401305001008, 117),
    (401305001118, 401305001, 401305001001, 401305001118, 401305001008, 118),
    (401305001119, 401305001, 401305001001, 401305001119, 401305001008, 119),
    (401305001120, 401305001, 401305001001, 401305001120, 401305001008, 120),
    (401305001121, 401305001, 401305001001, 401305001121, 401305001008, 121),
    (401305001122, 401305001, 401305001001, 401305001122, 401305001008, 122),
    (401305001123, 401305001, 401305001001, 401305001123, 401305001008, 123),
    (401305001124, 401305001, 401305001001, 401305001124, 401305001008, 124),
    (401305001125, 401305001, 401305001001, 401305001125, 401305001008, 125),
    (401305001126, 401305001, 401305001001, 401305001126, 401305001008, 126),
    (401305001127, 401305001, 401305001001, 401305001127, 401305001008, 127),
    (401305001128, 401305001, 401305001001, 401305001128, 401305001008, 128),
    (401305001129, 401305001, 401305001001, 401305001129, 401305001008, 129),
    (401305001130, 401305001, 401305001001, 401305001130, 401305001008, 130),
    (401305001131, 401305001, 401305001001, 401305001131, 401305001008, 131),
    (401305001132, 401305001, 401305001001, 401305001132, 401305001008, 132),
    (401305001133, 401305001, 401305001001, 401305001133, 401305001008, 133),
    (401305001134, 401305001, 401305001001, 401305001134, 401305001008, 134),
    (401305001135, 401305001, 401305001001, 401305001135, 401305001008, 135),
    (401305001136, 401305001, 401305001001, 401305001136, 401305001008, 136),
    (401305001137, 401305001, 401305001001, 401305001137, 401305001008, 137),
    (401305001138, 401305001, 401305001001, 401305001138, 401305001008, 138),
    (401305001139, 401305001, 401305001001, 401305001139, 401305001008, 139),
    (401305001140, 401305001, 401305001001, 401305001140, 401305001008, 140),
    (401305001141, 401305001, 401305001001, 401305001141, 401305001008, 141),
    (401305001142, 401305001, 401305001001, 401305001142, 401305001008, 142),
    -- Source: JSON, "pages[0].sections[8]"  (PANEER SPECIAL DISHES)
    (401305001143, 401305001, 401305001001, 401305001143, 401305001009, 143),
    (401305001144, 401305001, 401305001001, 401305001144, 401305001009, 144),
    (401305001145, 401305001, 401305001001, 401305001145, 401305001009, 145),
    (401305001146, 401305001, 401305001001, 401305001146, 401305001009, 146),
    (401305001147, 401305001, 401305001001, 401305001147, 401305001009, 147),
    (401305001148, 401305001, 401305001001, 401305001148, 401305001009, 148),
    (401305001149, 401305001, 401305001001, 401305001149, 401305001009, 149),
    (401305001150, 401305001, 401305001001, 401305001150, 401305001009, 150),
    (401305001151, 401305001, 401305001001, 401305001151, 401305001009, 151),
    (401305001152, 401305001, 401305001001, 401305001152, 401305001009, 152),
    (401305001153, 401305001, 401305001001, 401305001153, 401305001009, 153),
    (401305001154, 401305001, 401305001001, 401305001154, 401305001009, 154),
    (401305001155, 401305001, 401305001001, 401305001155, 401305001009, 155),
    (401305001156, 401305001, 401305001001, 401305001156, 401305001009, 156),
    (401305001157, 401305001, 401305001001, 401305001157, 401305001009, 157),
    (401305001158, 401305001, 401305001001, 401305001158, 401305001009, 158),
    (401305001159, 401305001, 401305001001, 401305001159, 401305001009, 159),
    (401305001160, 401305001, 401305001001, 401305001160, 401305001009, 160),
    (401305001161, 401305001, 401305001001, 401305001161, 401305001009, 161),
    (401305001162, 401305001, 401305001001, 401305001162, 401305001009, 162),
    (401305001163, 401305001, 401305001001, 401305001163, 401305001009, 163),
    (401305001164, 401305001, 401305001001, 401305001164, 401305001009, 164),
    (401305001165, 401305001, 401305001001, 401305001165, 401305001009, 165),
    (401305001166, 401305001, 401305001001, 401305001166, 401305001009, 166),
    (401305001167, 401305001, 401305001001, 401305001167, 401305001009, 167),
    (401305001168, 401305001, 401305001001, 401305001168, 401305001009, 168),
    (401305001169, 401305001, 401305001001, 401305001169, 401305001009, 169),
    -- Source: JSON, "pages[0].sections[9]"  (MUSHROOM SPECIAL DISHES)
    (401305001170, 401305001, 401305001001, 401305001170, 401305001010, 170),
    (401305001171, 401305001, 401305001001, 401305001171, 401305001010, 171),
    (401305001172, 401305001, 401305001001, 401305001172, 401305001010, 172),
    (401305001173, 401305001, 401305001001, 401305001173, 401305001010, 173),
    (401305001174, 401305001, 401305001001, 401305001174, 401305001010, 174),
    (401305001175, 401305001, 401305001001, 401305001175, 401305001010, 175),
    (401305001176, 401305001, 401305001001, 401305001176, 401305001010, 176),
    (401305001177, 401305001, 401305001001, 401305001177, 401305001010, 177),
    (401305001178, 401305001, 401305001001, 401305001178, 401305001010, 178),
    (401305001179, 401305001, 401305001001, 401305001179, 401305001010, 179),
    (401305001180, 401305001, 401305001001, 401305001180, 401305001010, 180),
    (401305001181, 401305001, 401305001001, 401305001181, 401305001010, 181),
    (401305001182, 401305001, 401305001001, 401305001182, 401305001010, 182),
    (401305001183, 401305001, 401305001001, 401305001183, 401305001010, 183),
    (401305001184, 401305001, 401305001001, 401305001184, 401305001010, 184),
    (401305001185, 401305001, 401305001001, 401305001185, 401305001010, 185),
    (401305001186, 401305001, 401305001001, 401305001186, 401305001010, 186),
    (401305001187, 401305001, 401305001001, 401305001187, 401305001010, 187),
    (401305001188, 401305001, 401305001001, 401305001188, 401305001010, 188),
    (401305001189, 401305001, 401305001001, 401305001189, 401305001010, 189),
    -- Source: JSON, "pages[0].sections[10]"  (CHOLE SPECIAL)
    (401305001190, 401305001, 401305001001, 401305001190, 401305001011, 190),
    (401305001191, 401305001, 401305001001, 401305001191, 401305001011, 191),
    -- Source: JSON, "pages[0].sections[11]"  (DAL KI DISHES)
    (401305001192, 401305001, 401305001001, 401305001192, 401305001012, 192),
    (401305001193, 401305001, 401305001001, 401305001193, 401305001012, 193),
    (401305001194, 401305001, 401305001001, 401305001194, 401305001012, 194),
    (401305001195, 401305001, 401305001001, 401305001195, 401305001012, 195),
    (401305001196, 401305001, 401305001001, 401305001196, 401305001012, 196),
    (401305001197, 401305001, 401305001001, 401305001197, 401305001012, 197),
    (401305001198, 401305001, 401305001001, 401305001198, 401305001012, 198),
    (401305001199, 401305001, 401305001001, 401305001199, 401305001012, 199),
    -- Source: JSON, "pages[0].sections[12]"  (PAPAD)
    (401305001200, 401305001, 401305001001, 401305001200, 401305001013, 200),
    (401305001201, 401305001, 401305001001, 401305001201, 401305001013, 201),
    (401305001202, 401305001, 401305001001, 401305001202, 401305001013, 202),
    (401305001203, 401305001, 401305001001, 401305001203, 401305001013, 203),
    (401305001204, 401305001, 401305001001, 401305001204, 401305001013, 204),
    (401305001205, 401305001, 401305001001, 401305001205, 401305001013, 205),
    -- Source: JSON, "pages[0].sections[13]"  (ROTI KI TOKRI)
    (401305001206, 401305001, 401305001001, 401305001206, 401305001014, 206),
    (401305001207, 401305001, 401305001001, 401305001207, 401305001014, 207),
    (401305001208, 401305001, 401305001001, 401305001208, 401305001014, 208),
    (401305001209, 401305001, 401305001001, 401305001209, 401305001014, 209),
    (401305001210, 401305001, 401305001001, 401305001210, 401305001014, 210),
    (401305001211, 401305001, 401305001001, 401305001211, 401305001014, 211),
    (401305001212, 401305001, 401305001001, 401305001212, 401305001014, 212),
    (401305001213, 401305001, 401305001001, 401305001213, 401305001014, 213),
    (401305001214, 401305001, 401305001001, 401305001214, 401305001014, 214),
    (401305001215, 401305001, 401305001001, 401305001215, 401305001014, 215),
    (401305001216, 401305001, 401305001001, 401305001216, 401305001014, 216),
    (401305001217, 401305001, 401305001001, 401305001217, 401305001014, 217),
    (401305001218, 401305001, 401305001001, 401305001218, 401305001014, 218),
    (401305001219, 401305001, 401305001001, 401305001219, 401305001014, 219),
    (401305001220, 401305001, 401305001001, 401305001220, 401305001014, 220),
    (401305001221, 401305001, 401305001001, 401305001221, 401305001014, 221),
    (401305001222, 401305001, 401305001001, 401305001222, 401305001014, 222),
    (401305001223, 401305001, 401305001001, 401305001223, 401305001014, 223),
    (401305001224, 401305001, 401305001001, 401305001224, 401305001014, 224),
    (401305001225, 401305001, 401305001001, 401305001225, 401305001014, 225),
    (401305001226, 401305001, 401305001001, 401305001226, 401305001014, 226),
    -- Source: JSON, "pages[1].sections[0]"  (RICE)
    (401305001227, 401305001, 401305001001, 401305001227, 401305001015, 227),
    (401305001228, 401305001, 401305001001, 401305001228, 401305001015, 228),
    (401305001229, 401305001, 401305001001, 401305001229, 401305001015, 229),
    (401305001230, 401305001, 401305001001, 401305001230, 401305001015, 230),
    (401305001231, 401305001, 401305001001, 401305001231, 401305001015, 231),
    (401305001232, 401305001, 401305001001, 401305001232, 401305001015, 232),
    (401305001233, 401305001, 401305001001, 401305001233, 401305001015, 233),
    (401305001234, 401305001, 401305001001, 401305001234, 401305001015, 234),
    (401305001235, 401305001, 401305001001, 401305001235, 401305001015, 235),
    (401305001236, 401305001, 401305001001, 401305001236, 401305001015, 236),
    (401305001237, 401305001, 401305001001, 401305001237, 401305001015, 237),
    (401305001238, 401305001, 401305001001, 401305001238, 401305001015, 238),
    (401305001239, 401305001, 401305001001, 401305001239, 401305001015, 239),
    (401305001240, 401305001, 401305001001, 401305001240, 401305001015, 240),
    (401305001241, 401305001, 401305001001, 401305001241, 401305001015, 241),
    (401305001242, 401305001, 401305001001, 401305001242, 401305001015, 242),
    (401305001243, 401305001, 401305001001, 401305001243, 401305001015, 243),
    (401305001244, 401305001, 401305001001, 401305001244, 401305001015, 244),
    (401305001245, 401305001, 401305001001, 401305001245, 401305001015, 245),
    (401305001246, 401305001, 401305001001, 401305001246, 401305001015, 246),
    (401305001247, 401305001, 401305001001, 401305001247, 401305001015, 247),
    (401305001248, 401305001, 401305001001, 401305001248, 401305001015, 248),
    (401305001249, 401305001, 401305001001, 401305001249, 401305001015, 249),
    -- Source: JSON, "pages[1].sections[1]"  (CHINESE SOUPS)
    (401305001250, 401305001, 401305001001, 401305001250, 401305001016, 250),
    (401305001251, 401305001, 401305001001, 401305001251, 401305001016, 251),
    (401305001252, 401305001, 401305001001, 401305001252, 401305001016, 252),
    (401305001253, 401305001, 401305001001, 401305001253, 401305001016, 253),
    (401305001254, 401305001, 401305001001, 401305001254, 401305001016, 254),
    (401305001255, 401305001, 401305001001, 401305001255, 401305001016, 255),
    (401305001256, 401305001, 401305001001, 401305001256, 401305001016, 256),
    (401305001257, 401305001, 401305001001, 401305001257, 401305001016, 257),
    -- Source: JSON, "pages[1].sections[2]"  (CHINESE STARTERS & GRAVY)
    (401305001258, 401305001, 401305001001, 401305001258, 401305001017, 258),
    (401305001259, 401305001, 401305001001, 401305001259, 401305001017, 259),
    (401305001260, 401305001, 401305001001, 401305001260, 401305001017, 260),
    (401305001261, 401305001, 401305001001, 401305001261, 401305001017, 261),
    (401305001262, 401305001, 401305001001, 401305001262, 401305001017, 262),
    (401305001263, 401305001, 401305001001, 401305001263, 401305001017, 263),
    (401305001264, 401305001, 401305001001, 401305001264, 401305001017, 264),
    (401305001265, 401305001, 401305001001, 401305001265, 401305001017, 265),
    (401305001266, 401305001, 401305001001, 401305001266, 401305001017, 266),
    (401305001267, 401305001, 401305001001, 401305001267, 401305001017, 267),
    (401305001268, 401305001, 401305001001, 401305001268, 401305001017, 268),
    (401305001269, 401305001, 401305001001, 401305001269, 401305001017, 269),
    (401305001270, 401305001, 401305001001, 401305001270, 401305001017, 270),
    (401305001271, 401305001, 401305001001, 401305001271, 401305001017, 271),
    (401305001272, 401305001, 401305001001, 401305001272, 401305001017, 272),
    -- Source: JSON, "pages[1].sections[3]"  (CHINESE STARTERS & GRAVY (CONTINUED))
    (401305001273, 401305001, 401305001001, 401305001273, 401305001017, 273),
    (401305001274, 401305001, 401305001001, 401305001274, 401305001017, 274),
    (401305001275, 401305001, 401305001001, 401305001275, 401305001017, 275),
    (401305001276, 401305001, 401305001001, 401305001276, 401305001017, 276),
    (401305001277, 401305001, 401305001001, 401305001277, 401305001017, 277),
    (401305001278, 401305001, 401305001001, 401305001278, 401305001017, 278),
    (401305001279, 401305001, 401305001001, 401305001279, 401305001017, 279),
    (401305001280, 401305001, 401305001001, 401305001280, 401305001017, 280),
    (401305001281, 401305001, 401305001001, 401305001281, 401305001017, 281),
    -- Source: JSON, "pages[1].sections[4]"  (CHINESE RICE AND NOODLES)
    (401305001282, 401305001, 401305001001, 401305001282, 401305001018, 282),
    (401305001283, 401305001, 401305001001, 401305001283, 401305001018, 283),
    (401305001284, 401305001, 401305001001, 401305001284, 401305001018, 284),
    (401305001285, 401305001, 401305001001, 401305001285, 401305001018, 285),
    (401305001286, 401305001, 401305001001, 401305001286, 401305001018, 286),
    (401305001287, 401305001, 401305001001, 401305001287, 401305001018, 287),
    (401305001288, 401305001, 401305001001, 401305001288, 401305001018, 288),
    (401305001289, 401305001, 401305001001, 401305001289, 401305001018, 289),
    (401305001290, 401305001, 401305001001, 401305001290, 401305001018, 290),
    (401305001291, 401305001, 401305001001, 401305001291, 401305001018, 291),
    (401305001292, 401305001, 401305001001, 401305001292, 401305001018, 292),
    (401305001293, 401305001, 401305001001, 401305001293, 401305001018, 293),
    (401305001294, 401305001, 401305001001, 401305001294, 401305001018, 294),
    (401305001295, 401305001, 401305001001, 401305001295, 401305001018, 295),
    (401305001296, 401305001, 401305001001, 401305001296, 401305001018, 296),
    (401305001297, 401305001, 401305001001, 401305001297, 401305001018, 297),
    (401305001298, 401305001, 401305001001, 401305001298, 401305001018, 298),
    (401305001299, 401305001, 401305001001, 401305001299, 401305001018, 299),
    (401305001300, 401305001, 401305001001, 401305001300, 401305001018, 300),
    -- Source: JSON, "pages[1].sections[5]"  (CHINESE TRIPLE RICE)
    (401305001301, 401305001, 401305001001, 401305001301, 401305001019, 301),
    (401305001302, 401305001, 401305001001, 401305001302, 401305001019, 302),
    (401305001303, 401305001, 401305001001, 401305001303, 401305001019, 303),
    (401305001304, 401305001, 401305001001, 401305001304, 401305001019, 304),
    (401305001305, 401305001, 401305001001, 401305001305, 401305001019, 305),
    (401305001306, 401305001, 401305001001, 401305001306, 401305001019, 306),
    (401305001307, 401305001, 401305001001, 401305001307, 401305001019, 307),
    (401305001308, 401305001, 401305001001, 401305001308, 401305001019, 308),
    (401305001309, 401305001, 401305001001, 401305001309, 401305001019, 309),
    (401305001310, 401305001, 401305001001, 401305001310, 401305001019, 310),
    (401305001311, 401305001, 401305001001, 401305001311, 401305001019, 311),
    (401305001312, 401305001, 401305001001, 401305001312, 401305001019, 312),
    (401305001313, 401305001, 401305001001, 401305001313, 401305001019, 313),
    -- Source: JSON, "pages[1].sections[6]"  (SALAD (RUSSIAN SALAD, TOSS SALAD))
    (401305001314, 401305001, 401305001001, 401305001314, 401305001020, 314),
    (401305001315, 401305001, 401305001001, 401305001315, 401305001020, 315),
    (401305001316, 401305001, 401305001001, 401305001316, 401305001020, 316),
    (401305001317, 401305001, 401305001001, 401305001317, 401305001020, 317),
    (401305001318, 401305001, 401305001001, 401305001318, 401305001020, 318),
    (401305001319, 401305001, 401305001001, 401305001319, 401305001020, 319),
    -- Source: JSON, "pages[1].sections[7]"  (COLD BEVERAGES)
    (401305001320, 401305001, 401305001001, 401305001320, 401305001021, 320),
    (401305001321, 401305001, 401305001001, 401305001321, 401305001021, 321),
    (401305001322, 401305001, 401305001001, 401305001322, 401305001021, 322),
    (401305001323, 401305001, 401305001001, 401305001323, 401305001021, 323),
    (401305001324, 401305001, 401305001001, 401305001324, 401305001021, 324),
    (401305001325, 401305001, 401305001001, 401305001325, 401305001021, 325),
    (401305001326, 401305001, 401305001001, 401305001326, 401305001021, 326),
    -- Source: JSON, "pages[1].sections[8]"  (COLD DRINKS)
    (401305001327, 401305001, 401305001001, 401305001327, 401305001022, 327),
    (401305001328, 401305001, 401305001001, 401305001328, 401305001022, 328),
    (401305001329, 401305001, 401305001001, 401305001329, 401305001022, 329),
    (401305001330, 401305001, 401305001001, 401305001330, 401305001022, 330),
    (401305001331, 401305001, 401305001001, 401305001331, 401305001022, 331),
    (401305001332, 401305001, 401305001001, 401305001332, 401305001022, 332),
    -- Source: JSON, "pages[1].sections[9]"  (DESSERTS)
    (401305001333, 401305001, 401305001001, 401305001333, 401305001023, 333),
    (401305001334, 401305001, 401305001001, 401305001334, 401305001023, 334),
    (401305001335, 401305001, 401305001001, 401305001335, 401305001023, 335),
    (401305001336, 401305001, 401305001001, 401305001336, 401305001023, 336),
    (401305001337, 401305001, 401305001001, 401305001337, 401305001023, 337),
    (401305001338, 401305001, 401305001001, 401305001338, 401305001023, 338),
    (401305001339, 401305001, 401305001001, 401305001339, 401305001023, 339),
    (401305001340, 401305001, 401305001001, 401305001340, 401305001023, 340),
    (401305001341, 401305001, 401305001001, 401305001341, 401305001023, 341),
    (401305001342, 401305001, 401305001001, 401305001342, 401305001023, 342),
    -- Source: JSON, "pages[1].sections[10]"  (MILK SHAKE)
    (401305001343, 401305001, 401305001001, 401305001343, 401305001024, 343),
    (401305001344, 401305001, 401305001001, 401305001344, 401305001024, 344),
    (401305001345, 401305001, 401305001001, 401305001345, 401305001024, 345),
    (401305001346, 401305001, 401305001001, 401305001346, 401305001024, 346),
    (401305001347, 401305001, 401305001001, 401305001347, 401305001024, 347),
    (401305001348, 401305001, 401305001001, 401305001348, 401305001024, 348),
    (401305001349, 401305001, 401305001001, 401305001349, 401305001024, 349),
    (401305001350, 401305001, 401305001001, 401305001350, 401305001024, 350),
    (401305001351, 401305001, 401305001001, 401305001351, 401305001024, 351),
    (401305001352, 401305001, 401305001001, 401305001352, 401305001024, 352),
    -- Source: JSON, "pages[1].sections[11]"  (FALOODAS)
    (401305001353, 401305001, 401305001001, 401305001353, 401305001025, 353),
    (401305001354, 401305001, 401305001001, 401305001354, 401305001025, 354),
    (401305001355, 401305001, 401305001001, 401305001355, 401305001025, 355),
    (401305001356, 401305001, 401305001001, 401305001356, 401305001025, 356),
    (401305001357, 401305001, 401305001001, 401305001357, 401305001025, 357),
    -- Source: JSON, "pages[1].sections[12]"  (FRESH JUICES)
    (401305001358, 401305001, 401305001001, 401305001358, 401305001026, 358),
    (401305001359, 401305001, 401305001001, 401305001359, 401305001026, 359),
    (401305001360, 401305001, 401305001001, 401305001360, 401305001026, 360),
    (401305001361, 401305001, 401305001001, 401305001361, 401305001026, 361),
    -- Source: JSON, "pages[1].sections[13]"  (RESTAURANT INFORMATION)
    (401305001362, 401305001, 401305001001, 401305001362, NULL, 362),
    (401305001363, 401305001, 401305001001, 401305001363, NULL, 363),
    (401305001364, 401305001, 401305001001, 401305001364, NULL, 364);

-- ---------------------------------------------------------------------
-- POST-LOAD CHECK: roll the whole transaction back if any count is off.
-- ---------------------------------------------------------------------
DO $$
DECLARE n BIGINT;
BEGIN
    SELECT count(*) INTO n FROM menu_item WHERE restaurant_id = 401305001;
    IF n <> 364 THEN RAISE EXCEPTION 'post-load check failed: menu_item = % (expected 364)', n; END IF;
    SELECT count(*) INTO n FROM menu_item_variant v JOIN menu_item i USING (menu_item_id) WHERE i.restaurant_id = 401305001;
    IF n <> 365 THEN RAISE EXCEPTION 'post-load check failed: menu_item_variant = % (expected 365)', n; END IF;
    SELECT count(*) INTO n FROM menu_item_price p JOIN menu_item_variant v USING (variant_id) JOIN menu_item i USING (menu_item_id) WHERE i.restaurant_id = 401305001;
    IF n <> 365 THEN RAISE EXCEPTION 'post-load check failed: menu_item_price = % (expected 365)', n; END IF;
    SELECT count(*) INTO n FROM menu_item_source WHERE source_id = 401305001;
    IF n <> 364 THEN RAISE EXCEPTION 'post-load check failed: menu_item_source = % (expected 364)', n; END IF;
    SELECT count(*) INTO n FROM menu_item_price_source WHERE source_id = 401305001;
    IF n <> 365 THEN RAISE EXCEPTION 'post-load check failed: menu_item_price_source = % (expected 365)', n; END IF;
    SELECT count(*) INTO n FROM menu_category WHERE restaurant_id = 401305001;
    IF n <> 26 THEN RAISE EXCEPTION 'post-load check failed: menu_category = % (expected 26)', n; END IF;
    SELECT count(*) INTO n FROM menu_board_category WHERE restaurant_id = 401305001;
    IF n <> 26 THEN RAISE EXCEPTION 'post-load check failed: menu_board_category = % (expected 26)', n; END IF;
    SELECT count(*) INTO n FROM menu_board_item WHERE restaurant_id = 401305001;
    IF n <> 364 THEN RAISE EXCEPTION 'post-load check failed: menu_board_item = % (expected 364)', n; END IF;
    SELECT count(*) INTO n FROM menu_item WHERE restaurant_id = 401305001 AND menu_category_id IS NULL;
    IF n <> 3 THEN RAISE EXCEPTION 'post-load check failed: menu_item (category NULL) = % (expected 3)', n; END IF;
    SELECT count(*) INTO n FROM menu_item_addon_group g JOIN menu_item i USING (menu_item_id) WHERE i.restaurant_id = 401305001;
    IF n <> 37 THEN RAISE EXCEPTION 'post-load check failed: menu_item_addon_group = % (expected 37)', n; END IF;
    SELECT count(*) INTO n FROM restaurant_phone WHERE restaurant_id = 401305001;
    IF n <> 2 THEN RAISE EXCEPTION 'post-load check failed: restaurant_phone = % (expected 2)', n; END IF;
    SELECT count(*) INTO n FROM restaurant_tag WHERE restaurant_id = 401305001;
    IF n <> 5 THEN RAISE EXCEPTION 'post-load check failed: restaurant_tag = % (expected 5)', n; END IF;
    RAISE NOTICE 'Ashraya 401305001 loaded: 364 items, 365 variants/prices, 26 categories - all checks passed';
END $$;

ROLLBACK;

-- =====================================================================
-- TRAILING BLOCK 1 -- needs_review rows and rows with confidence < 0.8
-- =====================================================================
-- menu_item / menu_item_source:
--   menu_item_id 401305001059  'Tomato Omlet Sandwich'  (status needs_review, name confidence 0.90000)
--       'Omlet' in a pure_veg menu - classified veg from the restaurant-level pure_veg flag; confirm it is not egg
--   menu_item_id 401305001060  'Tomato Omlet Grilled Sandwich'  (status needs_review, name confidence 0.90000)
--       'Omlet' in a pure_veg menu - classified veg from the restaurant-level pure_veg flag; confirm it is not egg
--   menu_item_id 401305001107  'Zhinge Masala Fry'  (status needs_review, name confidence 0.90000)
--       'Zhinge' commonly means prawns in Marathi - classified veg from the restaurant-level pure_veg flag; confirm it is a vegetable dish
--   menu_item_id 401305001148  'Paneer Kadai'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Paneer Kadai / Handi': head word 'Paneer' carried onto 2nd dish
--   menu_item_id 401305001149  'Paneer Handi'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Paneer Kadai / Handi': head word 'Paneer' carried onto 2nd dish
--   menu_item_id 401305001162  'Paneer Malwani Masala'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Paneer Malwani | Agri | Saoji Masala': 'Paneer' and 'Masala' carried onto all three (pattern mirrors 'Veg Malwani/Agri/Saoji Masala' in MAIN COURSE)
--   menu_item_id 401305001163  'Paneer Agri Masala'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Paneer Malwani | Agri | Saoji Masala': 'Paneer' and 'Masala' carried onto all three (pattern mirrors 'Veg Malwani/Agri/Saoji Masala' in MAIN COURSE)
--   menu_item_id 401305001164  'Paneer Saoji Masala'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Paneer Malwani | Agri | Saoji Masala': 'Paneer' and 'Masala' carried onto all three (pattern mirrors 'Veg Malwani/Agri/Saoji Masala' in MAIN COURSE)
--   menu_item_id 401305001171  'Mushroom'  (status needs_review, name confidence 0.50000)
--       name is just 'Mushroom' - looks truncated (Paneer list has 'Paneer Mutter | Paneer Chana' at this position)
--   menu_item_id 401305001174  'Mushroom Kadai'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Mushroom Kadai / Handi': head word 'Mushroom' carried onto 2nd dish
--   menu_item_id 401305001175  'Mushroom Handi'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Mushroom Kadai / Handi': head word 'Mushroom' carried onto 2nd dish
--   menu_item_id 401305001182  'Mushroom Korma'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Mushroom Korma / Masala': head word carried; 2nd dish duplicates 'Mushroom Masala' listed earlier in the same section
--   menu_item_id 401305001183  'Mushroom Masala'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Mushroom Korma / Masala': head word carried; 2nd dish duplicates 'Mushroom Masala' listed earlier in the same section
--   menu_item_id 401305001186  'Mushroom Malwani Masala'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Mushroom Malwani | Agri | Saoji Masala': 'Mushroom' and 'Masala' carried onto all three
--   menu_item_id 401305001187  'Mushroom Agri Masala'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Mushroom Malwani | Agri | Saoji Masala': 'Mushroom' and 'Masala' carried onto all three
--   menu_item_id 401305001188  'Mushroom Saoji Masala'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Mushroom Malwani | Agri | Saoji Masala': 'Mushroom' and 'Masala' carried onto all three
--   menu_item_id 401305001203  'Khichcha Papad Roasted'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Khichcha Papad Roasted | Fried': 'Khichcha Papad' carried onto 2nd dish
--   menu_item_id 401305001204  'Khichcha Papad Fried'  (status needs_review, name confidence 0.70000)
--       name reconstructed - 'Khichcha Papad Roasted | Fried': 'Khichcha Papad' carried onto 2nd dish
-- menu_item_price / menu_item_price_source:
--   price_id 401305001059  'Tomato Omlet Sandwich' = 170.00  (status needs_review, confidence 0.60000)
--       price 170 is out of line: 'Tomato Omlet Grilled Sandwich' is 120 and every other plain-vs-grilled pair here has grilled costing more
--   price_id 401305001240  'Dal Khichdi' = 190.00  (status needs_review, confidence 0.65000)
--       'Dal Khichdi' 190 vs 'Dal Khichdi Tadka' 160: tadka version cheaper than plain - possible swap / misread
--   price_id 401305001241  'Dal Khichdi Tadka' = 160.00  (status needs_review, confidence 0.65000)
--       'Dal Khichdi Tadka' 160 vs 'Dal Khichdi' 190: tadka version cheaper than plain - possible swap / misread
-- Other split lines (A/C kind) are NOT in the list above: both dishes keep the
-- printed price, name confidence 0.90 / 0.85, price confidence 0.85. Listed here so you
-- can spot-check them; each pair shares a split_group_key (P/S/I = 1-based page / section / item
-- position in the JSON, i.e. P1S12I2 = pages[0].sections[11].columns[0].items[1]):
--   401305001-P1S12I2: Dal Fry Tadka | Butter Dal Fry  @ 130.00
--   401305001-P1S12I3: Dal Palak | Dal Kolhapuri  @ 120.00
--   401305001-P1S13I1: Roasted Papad | Fried Papad  @ 30.00
--   401305001-P1S14I7: Garlic Naan | Garlic Kulcha  @ 50.00
--   401305001-P1S14I8: Butter Garlic Naan | Butter Garlic Kulcha  @ 60.00
--   401305001-P1S2I16: Cheese Pakoda | Paneer Pakoda  @ 220.00
--   401305001-P1S2I4: Dahi Idli | Dahi Vada  @ 110.00
--   401305001-P1S3I12: Onion Masala Dosa | Onion Rava Dosa  @ 120.00
--   401305001-P1S3I24: Tomato Onion Uttappa | Masala Uttappa  @ 110.00
--   401305001-P1S8I1: Chana Masala | Alu Mutter  @ 180.00
--   401305001-P1S8I10: Veg Makhanwala | Veg Jalfrazie  @ 200.00
--   401305001-P1S8I12: Veg Kadai | Veg Handi  @ 200.00
--   401305001-P1S8I13: Veg Mughlai | Veg Kheema  @ 200.00
--   401305001-P1S8I14: Veg Tawa Masala | Veg Lababdar  @ 210.00
--   401305001-P1S8I18: Veg Malwani Masala | Veg Agri Masala  @ 230.00
--   401305001-P1S8I2: Plain Palak | Alu Palak  @ 180.00
--   401305001-P1S8I20: Malai Kofta | Punjabi Curry Kofta  @ 230.00
--   401305001-P1S8I25: Kaju Masala | Kaju Paneer Masala  @ 270.00
--   401305001-P1S8I3: Alu Gobi | Alu Methi  @ 180.00
--   401305001-P1S8I5: Mix Veg | Veg Khurma  @ 180.00
--   401305001-P1S8I7: Methi Mutter Malai | Methi Mutter Masala  @ 200.00
--   401305001-P1S8I8: Veg Kolhapuri | Veg Jaipuri  @ 200.00
--   401305001-P1S9I2: Paneer Mutter | Paneer Chana  @ 240.00
--   401305001-P1S9I6: Paneer Jalfrazie | Paneer Makhanwala  @ 240.00
--   401305001-P1S9I7: Paneer Palak | Paneer Lasuni Palak  @ 240.00
--   401305001-P2S2I1: Tomato Soup | Palak Soup  @ 120.00
--   401305001-P2S4I7: Mushroom Chilly | Baby Corn Chilly  @ 230.00

-- =====================================================================
-- TRAILING BLOCK 2 -- restaurant-level content with no (or only a partial) schema home
-- =====================================================================
--   price_per_person "INR 200-400" (JSON restaurant.price_per_person): restaurant has cost_for_two_amount only; a per-person range is not stored, and doubling it would be a guess.
--   email / website: empty in the JSON -> NULL.
--   pages[0].sections[6]: "PLEASE NOTE: ORDER ONCE PLACED CANNOT BE CANCELLED" (also in the info box): no column.
--   pages[1].sections[13]: "We Also Undertake Party Orders": no column. restaurant_service_mode / service_mode "bulk_catering" is the natural home if you want it recorded.
--   pages[1]: "THANK YOU!" - ignored.
--   pages[1].sections[13] "Timing : 9:00 am to 11:15 pm" and JSON restaurant.timings "06 am-12 am" CONFLICT -> restaurant_hours left empty. After confirming, run ONE of these (day_of_week 1 = Monday):
--        -- Option A: menu info-box hours, 09:00 - 23:15
--        -- INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
--        -- SELECT 4013050010000 + d, 401305001, d, 1, '09:00', '23:15' FROM generate_series(1, 7) AS d;
--        -- Option B: JSON header hours, 06:00 - midnight (12 am); closes_at 00:00 is earlier than opens_at = spans to midnight
--        -- INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
--        -- SELECT 4013050010000 + d, 401305001, d, 1, '06:00', '00:00' FROM generate_series(1, 7) AS d;
--   Delivery: loaded as self-delivery (SELF) because the JSON names no third-party partner. No delivery radius is given.
--   Tax: "*GOVT TAXES EXTRA AS APPLICABLE" -> tax_inclusion_code = exclusive on all prices. The JSON has no GST field, rate or GSTIN, so there was nothing to cross-check and tax_regime_code / tax_rate are NULL.
--   Images: pages[0] 1000468484.jpg and pages[1] 1000468486.jpg are file names only (no storage URI), so media_asset / menu_extraction_image were not created.
--   Tags that were INFERRED, not stated (drop the rows in restaurant_tag if you disagree): JAIN_AVAILABLE (6 items named "Jain ..."), cuisine_chinese, cuisine_punjabi, cuisine_southindian (from section headers).
--   Categories: "(CONTINUED)" section merged; RESTAURANT INFORMATION not created as a category (3 items left with menu_category_id NULL for curation: 401305001362, 401305001363, 401305001364).
--   Add-ons: scope = every item in the section (see the add-on block). Cold Coffee with Ice Cream excluded from the ice-cream add-on.
--   Source spellings kept verbatim (not corrected): Nes Coffee, Vanila Ice Cream Scoop, Veg Khurma, Pineapple Raitha / Veg Raitha / Boondi Raitha, Zhinge Masala Fry, Paper Sada/Masala Dosa, Chickoo Milk Shake, Veg. Aashraya's Special.
--   brand / brand_menu_template: JSON names no brand -> nothing to check.
--   change_event_outbox: not populated (payload shape not specified) - integration follow-up.
