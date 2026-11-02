-- =============================================================================
-- Khaustan onboarding script: Hanuman Veg. Treat  (v3)
-- Source docx: Hanuman_Veg_Treat_Menu_transcribed.docx
-- Schema: khaustan-full-platform-postgresql.sql, database "KhaustanRestaurantMenu"
--   (the actual DDL you supplied -- every column/constraint below is read
--   directly from it, nothing here is inferred from the earlier prompt doc)
-- =============================================================================
--
-- CORRECTION FROM THE PREVIOUS VERSION:
--   That version's header claimed a "ck_menu_item_price_amount" bug (boolean
--   compared to integer literals). Having now read the actual DDL, that
--   constraint is written correctly --
--     CHECK ((is_market_price = TRUE AND price_amount IS NULL)
--            OR (is_market_price = FALSE AND price_amount IS NOT NULL AND price_amount >= 0))
--   -- both sides are boolean-to-boolean comparisons. That claim came from
--   the earlier prompt document's own prose, which this script trusted
--   without independent verification; it does not hold up against your
--   actual schema, and I'm retracting it rather than repeating it.
--
-- WHAT A REAL SCHEMA READ CHANGED (previously inferred/deferred, now exact):
--   - bar_license_type is NOT NULL DEFAULT 'none', CHECK IN ('none',
--     'beer_wine_only','full_bar') -- confirms 'none' was the right value.
--   - split_group_key (menu_item) is a real column for exactly this
--     situation ("one printed line, split into several rows"). Now
--     populated for all 21 compressed lines that expanded into two items.
--   - menu_item_availability.day_of_week is nullable (NULL = every day),
--     unlike restaurant_hours.day_of_week (NOT NULL, one row per day).
--     Previously deferred entirely for lack of this fact; now populated for
--     Upma/Sheera and the Pav Bhaji / Lunch categories' time windows.
--   - menu_item_price_source(price_id, source_id, extraction_batch_id,
--     confidence) is real and has no verification_status_code of its own
--     (that lives on menu_item_price directly). Previously skipped for lack
--     of a confirmed column list; now populated for every price.
--   - restaurant_tag(restaurant_tag_id, restaurant_id, tag_id, value_text,
--     value_number, value_boolean, ...) is real. platform_tag.tag_scope is
--     CHECK-constrained to ('restaurant_format','restaurant_filter',
--     'menu_item') -- NOT 'restaurant', which is what this script would
--     have guessed. "Jain dishes available" is now recorded as a
--     platform_tag/restaurant_tag pair with tag_scope='restaurant_filter'.
--   - service_mode / restaurant_service_mode and delivery_provider /
--     restaurant_delivery / restaurant_delivery_provider are all real and
--     fully specified. "FREE HOME DELIVERY" + "TAKE AWAY MENU" are now
--     recorded as service modes, plus a self-delivery capability row and a
--     'self' delivery_provider link with a fixed Rs 0 delivery charge.
--   - canonical_dish also carries food_classification_code and
--     default_protein_type_id, so those are now set to match each dish's
--     menu_item-level classification, not left NULL.
--
-- CRITICAL FIX -- protein_type and service_mode ship EMPTY:
--   The schema file contains zero INSERT statements anywhere (confirmed by
--   search) -- every lookup table, including protein_type and service_mode,
--   is created with no seed rows. The previous version of this script
--   looked up protein_type WHERE code = 'egg' and would silently match
--   ZERO rows on a genuinely fresh database -- not an error, just three
--   Omlet items quietly never inserted. This version seeds both lookup
--   tables (all 7 protein_type codes, all 6 service_mode codes) up front,
--   using the same identify-or-create style as everything else, so it's
--   safe to run before or after any other seeding you may already have.
--
-- CLIENT COMPATIBILITY (unchanged from the previous fix):
--   No psql meta-commands (\connect, \gset, \if, \echo, \q) and no
--   ":variable" client binds anywhere -- this runs as plain SQL in
--   pgAdmin4, psql, DBeaver, or anything else that speaks Postgres.
--   Session values (restaurant_id, source_id, extraction_batch_id) are
--   carried in a one-row TEMP TABLE (khaustan_onboarding_ctx), dropped
--   automatically at COMMIT.
--
-- ABOUT THE ACCOMPANYING SCHEMA FILE:
--   The schema file you attached deploys FOUR separate databases with a
--   psql \connect + \gexec preamble per database -- also psql-only, and
--   CREATE DATABASE additionally cannot run inside the same
--   transaction/batch as the CREATE TABLEs that follow it in any client,
--   which is exactly why the original script used psql to work around it.
--   The companion file khaustan_restaurantmenu_schema.sql in this delivery
--   is the KhaustanRestaurantMenu portion only (the one this insert script
--   needs) with that preamble replaced by a plain instruction. See its own
--   header for the two-step run order.
--
-- STILL DEFERRED -- genuinely unresolved even with the real schema in hand:
--   - (Zomato/Swiggy delivery links and menu_board/menu_category, both
--     previously deferred here, are now added -- see the v4 block above.)
--   - tax_regime_code / tax_inclusion_code / tax_rate on menu_item_price:
--     the schema's own comment marks tax_regime_code "open/externally-
--     driven," and no coding convention is given anywhere in this DDL.
--   - Which specific items the three blanket surcharge notes (ghee/butter
--     Rs 20, pizza topping/cheese Rs 40, bread-toast Rs 20) apply to --
--     menu_item_charge's columns are now fully known (see the UNMAPPED
--     block at the end for the exact list), but the qualifying item set
--     still isn't stated unambiguously in the docx.
--   All three are spelled out in the UNMAPPED block at the end, same as
--   before, now with exact column lists instead of "table name unknown."
--
-- TESTING PERFORMED: this environment has no PostgreSQL server and no
-- network access to install one, so nothing here has been executed against
-- a live database. What this script's build process DID do: (1) parse your
-- actual DDL into a table/column/NOT-NULL/default/CHECK map, (2) validate
-- every INSERT's column list against that map programmatically -- confirmed
-- zero missing-required-column errors and zero references to non-existent
-- columns -- and (3) re-verify parens/quotes balance and every :variable/\
-- artifact is gone, the same way the previous version was checked. Please
-- still run this against a disposable/staging database first.
-- =============================================================================

-- Ensure your pgAdmin4 Query Tool (or other client) is connected to the
-- "KhaustanRestaurantMenu" database before running this script.
--\connect "KhaustanRestaurantMenu"

BEGIN;

-- -----------------------------------------------------------------------
-- Requested deterministic ID namespaces
-- Each namespace starts independently at 400086001001.
-- -----------------------------------------------------------------------
DROP SEQUENCE IF EXISTS pg_temp.khaustan_menu_item_id_seq;
DROP SEQUENCE IF EXISTS pg_temp.khaustan_variant_id_seq;
DROP SEQUENCE IF EXISTS pg_temp.khaustan_price_id_seq;
DROP SEQUENCE IF EXISTS pg_temp.khaustan_availability_id_seq;
DROP SEQUENCE IF EXISTS pg_temp.khaustan_menu_board_id_seq;
DROP SEQUENCE IF EXISTS pg_temp.khaustan_menu_category_id_seq;
DROP SEQUENCE IF EXISTS pg_temp.khaustan_menu_board_item_id_seq;

CREATE TEMP SEQUENCE khaustan_menu_item_id_seq START WITH 400086001001;
CREATE TEMP SEQUENCE khaustan_variant_id_seq START WITH 400086001001;
CREATE TEMP SEQUENCE khaustan_price_id_seq START WITH 400086001001;
CREATE TEMP SEQUENCE khaustan_availability_id_seq START WITH 400086001001;
CREATE TEMP SEQUENCE khaustan_menu_board_id_seq START WITH 400086001001;
CREATE TEMP SEQUENCE khaustan_menu_category_id_seq START WITH 400086001001;
CREATE TEMP SEQUENCE khaustan_menu_board_item_id_seq START WITH 400086001001;

-- menu_category/menu_board/menu_board_item IDs use the three dedicated
-- sequences above (each independently starting at 400086001001, same
-- convention as menu_item/variant/price/availability). menu_board_category
-- itself has no standalone ID column -- its identity is the
-- (restaurant_id, menu_board_id, menu_category_id, display_sequence) row,
-- so restaurant_id (400086001) plus the menu_board_id/menu_category_id
-- values from those two sequences are what ties it to this namespace.

-- -----------------------------------------------------------------------
-- ID generation (Step 5): one shared sequence, seeded past every existing
-- max id this script could collide with.
-- -----------------------------------------------------------------------
DO $do$
DECLARE
  v_max BIGINT;
BEGIN
  SELECT GREATEST(
    COALESCE((SELECT MAX(establishment_id) FROM establishment), 0),
    COALESCE((SELECT MAX(restaurant_id) FROM restaurant), 0),
    COALESCE((SELECT MAX(restaurant_phone_id) FROM restaurant_phone), 0),
    COALESCE((SELECT MAX(protein_type_id) FROM protein_type), 0),
    COALESCE((SELECT MAX(service_mode_id) FROM service_mode), 0),
    COALESCE((SELECT MAX(tag_id) FROM platform_tag), 0),
    COALESCE((SELECT MAX(restaurant_tag_id) FROM restaurant_tag), 0),
    COALESCE((SELECT MAX(delivery_provider_id) FROM delivery_provider), 0),
    COALESCE((SELECT MAX(restaurant_delivery_provider_id) FROM restaurant_delivery_provider), 0),
    COALESCE((SELECT MAX(canonical_dish_id) FROM canonical_dish), 0),
    COALESCE((SELECT MAX(canonical_dish_name_id) FROM canonical_dish_name), 0),
    COALESCE((SELECT MAX(menu_item_id) FROM menu_item), 0),
    COALESCE((SELECT MAX(variant_id) FROM menu_item_variant), 0),
    COALESCE((SELECT MAX(price_id) FROM menu_item_price), 0),
    COALESCE((SELECT MAX(availability_id) FROM menu_item_availability), 0),
    COALESCE((SELECT MAX(source_id) FROM source_record), 0),
    COALESCE((SELECT MAX(extraction_batch_id) FROM menu_extraction_batch), 0)
  ) INTO v_max;
  EXECUTE format('CREATE SEQUENCE IF NOT EXISTS khaustan_onboarding_id_seq START WITH %s', v_max + 1);
END $do$;

-- -----------------------------------------------------------------------
-- Session context -- see CLIENT COMPATIBILITY note above.
-- -----------------------------------------------------------------------
CREATE TEMP TABLE khaustan_onboarding_ctx (
  restaurant_id       BIGINT,
  source_id           BIGINT,
  extraction_batch_id BIGINT
) ON COMMIT DROP;
INSERT INTO khaustan_onboarding_ctx DEFAULT VALUES;

-- -----------------------------------------------------------------------
-- Establishment + restaurant, identify-or-create.
-- has_bar = FALSE, bar_license_type = 'none': no bar/alcohol section or
-- item appears anywhere in the menu -- inferred, not literally stated.
-- veg_nonveg_status intentionally left NULL: see the NEEDS_REVIEW note on
-- the three "Omlet" items -- this restaurant is either pure_veg or
-- veg_and_nonveg depending on how that same ambiguity resolves, so it is
-- not asserted here either way.
-- -----------------------------------------------------------------------
DO $do$
DECLARE
  v_establishment_id BIGINT := 400086001;
  v_restaurant_id    BIGINT := 400086001;
BEGIN
  INSERT INTO establishment (
    establishment_id, name, normalized_name, address_line1, locality, postal_code,
    city, state, country_code, latitude, longitude
  )
  VALUES (
    v_establishment_id,
    'Hanuman Veg. Treat',
    lower(trim('Hanuman Veg. Treat')),
    'Next to Neelkant Business Park',
    'Vidhyavihar (W)',
    '400086',
    'Mumbai',
    'Maharashtra',
    'IN',
    19.080593041694897, 72.89604989234579
  )
  ON CONFLICT DO NOTHING;

  INSERT INTO restaurant (
    restaurant_id, establishment_id, display_name, normalized_name,
    has_bar, bar_license_type
  )
  VALUES (
    v_restaurant_id,
    v_establishment_id,
    'Hanuman Veg. Treat',
    lower(trim('Hanuman Veg. Treat')),
    FALSE,
    'none'
  )
  ON CONFLICT DO NOTHING;

  UPDATE khaustan_onboarding_ctx
  SET restaurant_id = v_restaurant_id;
END $do$;

-- -----------------------------------------------------------------------
-- Re-run guard: RAISE EXCEPTION aborts the whole transaction in any client
-- if this exact docx was already fully processed for this restaurant.
-- -----------------------------------------------------------------------
DO $do$
DECLARE
  v_already_processed BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM menu_extraction_batch
    WHERE restaurant_id = (SELECT restaurant_id FROM khaustan_onboarding_ctx)
      AND source_id IN (SELECT source_id FROM source_record WHERE source_uri = 'Hanuman_Veg_Treat_Menu_transcribed.docx')
      AND status_code = 'completed'
  ) INTO v_already_processed;

  IF v_already_processed THEN
    RAISE EXCEPTION 'Khaustan onboarding: % has already been fully processed for this restaurant (menu_extraction_batch.status_code = completed). Aborting without inserting menu items again.', 'Hanuman_Veg_Treat_Menu_transcribed.docx';
  END IF;
END $do$;

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES ( 400086001, 'ai_menu_extraction', 'Hanuman_Veg_Treat_Menu_transcribed.docx');
UPDATE khaustan_onboarding_ctx
SET source_id = (SELECT source_id FROM source_record WHERE source_uri = 'Hanuman_Veg_Treat_Menu_transcribed.docx' ORDER BY created_at DESC LIMIT 1);

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
SELECT nextval('khaustan_onboarding_id_seq'), ctx.restaurant_id, ctx.source_id, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed'
FROM khaustan_onboarding_ctx ctx;
UPDATE khaustan_onboarding_ctx
SET extraction_batch_id = (SELECT extraction_batch_id FROM menu_extraction_batch WHERE source_id = khaustan_onboarding_ctx.source_id);

-- -----------------------------------------------------------------------
-- Phones. All four numbers are printed together with no marked primary;
-- the first-listed is designated primary here as a defensible default --
-- flagged in the trailing notes since it is inferred, not stated. None are
-- marked is_personal_number (defaults FALSE / business line) -- the docx
-- gives no way to tell if any of these are an individual's personal mobile
-- rather than a dedicated business line; worth a DPDP-conscious second look.
-- -----------------------------------------------------------------------
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
SELECT nextval('khaustan_onboarding_id_seq'), ctx.restaurant_id, x.phone_number, x.is_primary
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES
  ('7045547945', TRUE),
  ('7045547378', FALSE),
  ('8169686722', FALSE),
  ('8369526996', FALSE)
) AS x(phone_number, is_primary);

-- No restaurant_hours inserted: the docx states no overall open/close
-- times anywhere (only item-specific windows, now modeled via
-- menu_item_availability further below).

-- -----------------------------------------------------------------------
-- Service modes: "TAKE AWAY MENU" (the docx's own title) and "FREE HOME
-- DELIVERY" (explicit footer text) are both confirmed. dine_in is NOT
-- asserted -- plausible for a restaurant with a street address, but not
-- explicitly stated, so left unset rather than guessed.
-- -----------------------------------------------------------------------
INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id, is_active, notes)
SELECT ctx.restaurant_id, sm.service_mode_id, TRUE, x.notes
FROM khaustan_onboarding_ctx ctx
CROSS JOIN (VALUES ('takeaway', 'Docx is titled "TAKE AWAY MENU".'),
                    ('delivery', 'Docx footer states "FREE HOME DELIVERY".')) AS x(code, notes)
JOIN service_mode sm ON sm.code = x.code;

-- -----------------------------------------------------------------------
-- Delivery capability. self_delivery_min_order_amount left NULL: no
-- minimum order amount is stated anywhere in the docx.
-- -----------------------------------------------------------------------
INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available, self_delivery_min_order_amount)
SELECT ctx.restaurant_id, TRUE, TRUE, NULL FROM khaustan_onboarding_ctx ctx;

-- 'self' delivery_provider is a platform-wide lookup.
-- Per instruction, this script does NOT insert lookup records. If the
-- 'self' provider already exists, create the restaurant link; otherwise no
-- lookup/link row is created.
INSERT INTO restaurant_delivery_provider (
  restaurant_delivery_provider_id, restaurant_id, delivery_provider_id,
  delivery_charge_type_code, base_delivery_charge, effective_from
)
SELECT
  nextval('khaustan_onboarding_id_seq'),
  ctx.restaurant_id,
  dp.delivery_provider_id,
  'fixed',
  0.00,
  (clock_timestamp() AT TIME ZONE 'UTC')
FROM khaustan_onboarding_ctx ctx
JOIN delivery_provider dp ON dp.provider_code = 'SELF';

-- -----------------------------------------------------------------------
-- "Jain dishes are available" -- platform_tag is a platform-wide lookup.
-- Per instruction, this script does NOT insert lookup records. If the
-- lookup tag already exists, create the restaurant link; otherwise no tag
-- or link row is created.
-- -----------------------------------------------------------------------
INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id, value_boolean)
SELECT
  nextval('khaustan_onboarding_id_seq'),
  ctx.restaurant_id,
  pt.tag_id,
  TRUE
FROM khaustan_onboarding_ctx ctx
JOIN platform_tag pt ON pt.tag_code = 'JAIN_AVAILABLE';

-- -----------------------------------------------------------------------
-- Canonical dishes: one row per distinct normalized dish name across the
-- whole menu, batched into one set-based statement (safe because
-- canonical_dish's identity key is normalized_name and the candidate list
-- is de-duplicated in Python before this script is generated -- see the
-- header of the previous version for the fuller rationale; menu_item
-- itself is still one statement per printed line, unbatched, below).
-- -----------------------------------------------------------------------
WITH candidate_dishes(canonical_name, normalized_name, food_classification_code, protein_code) AS (
  VALUES
    ('Upma (Mor. 8.00 to 11.00 am)', 'upma (mor. 8.00 to 11.00 am)', 'veg', NULL),
    ('Sheera (Mor. 8.00 to 11.00 am)', 'sheera (mor. 8.00 to 11.00 am)', 'veg', NULL),
    ('Steam Idli', 'steam idli', 'veg', NULL),
    ('Butter Idli', 'butter idli', 'veg', NULL),
    ('Fried Idli', 'fried idli', 'veg', NULL),
    ('Dahi Idli', 'dahi idli', 'veg', NULL),
    ('Dahi Vada', 'dahi vada', 'veg', NULL),
    ('Medu Vada', 'medu vada', 'veg', NULL),
    ('Idli Vada', 'idli vada', 'veg', NULL),
    ('Batata Vada', 'batata vada', 'veg', NULL),
    ('Mix Vada', 'mix vada', 'veg', NULL),
    ('Misal Pav', 'misal pav', 'veg', NULL),
    ('Puri Bhaji', 'puri bhaji', 'veg', NULL),
    ('Finger Chips', 'finger chips', 'veg', NULL),
    ('Sabudana Vada', 'sabudana vada', 'veg', NULL),
    ('Sweet Kachori', 'sweet kachori', 'veg', NULL),
    ('Sada Dosa', 'sada dosa', 'veg', NULL),
    ('Rava Dosa', 'rava dosa', 'veg', NULL),
    ('Masala Dosa', 'masala dosa', 'veg', NULL),
    ('Rava Masal Dosa', 'rava masal dosa', 'veg', NULL),
    ('Mysore Sada Dosa', 'mysore sada dosa', 'veg', NULL),
    ('Mysore Masala Dosa', 'mysore masala dosa', 'veg', NULL),
    ('Paper Sada Dosa', 'paper sada dosa', 'veg', NULL),
    ('Paper Masal Dosa', 'paper masal dosa', 'veg', NULL),
    ('Mysore Rava Dosa', 'mysore rava dosa', 'veg', NULL),
    ('Mysore Rava Masala Dosa', 'mysore rava masala dosa', 'veg', NULL),
    ('Plain Uttappam', 'plain uttappam', 'veg', NULL),
    ('Onion Uttappam', 'onion uttappam', 'veg', NULL),
    ('Tomato Uttappam', 'tomato uttappam', 'veg', NULL),
    ('Masala Uttappam', 'masala uttappam', 'veg', NULL),
    ('Tomato Omlet', 'tomato omlet', 'egg', 'egg'),
    ('Cheese Tomato Omlet', 'cheese tomato omlet', 'egg', 'egg'),
    ('Cheese Tomato Uttappam', 'cheese tomato uttappam', 'veg', NULL),
    ('Cheese Onion Uttappam', 'cheese onion uttappam', 'veg', NULL),
    ('Spring Rol Dosa', 'spring rol dosa', 'veg', NULL),
    ('Palak Dosa', 'palak dosa', 'veg', NULL),
    ('Palak Masala Dosa', 'palak masala dosa', 'veg', NULL),
    ('Cheese Dosa', 'cheese dosa', 'veg', NULL),
    ('Cheese Masala Dosa', 'cheese masala dosa', 'veg', NULL),
    ('Schezwan Sada Dosa', 'schezwan sada dosa', 'veg', NULL),
    ('Schezwan Masala Dosa', 'schezwan masala dosa', 'veg', NULL),
    ('Benne Dosa', 'benne dosa', 'veg', NULL),
    ('Benne Masala Dosa', 'benne masala dosa', 'veg', NULL),
    ('Pav Bhaji', 'pav bhaji', 'veg', NULL),
    ('Cheese Pav Bhaji', 'cheese pav bhaji', 'veg', NULL),
    ('Khada Pav Bhaji', 'khada pav bhaji', 'veg', NULL),
    ('Cheese Khada Pav Bhaji', 'cheese khada pav bhaji', 'veg', NULL),
    ('Mushroom Pav Bhaji', 'mushroom pav bhaji', 'veg', NULL),
    ('Paneer Pav Bhaji', 'paneer pav bhaji', 'veg', NULL),
    ('Jain Pav Bhaji', 'jain pav bhaji', 'veg', NULL),
    ('Jain Cheese Pav Bhaji', 'jain cheese pav bhaji', 'veg', NULL),
    ('Only Bhaji', 'only bhaji', 'veg', NULL),
    ('Masala Pav (2 Pcs)', 'masala pav (2 pcs)', 'veg', NULL),
    ('Cheese Masala Pav (2 Pcs)', 'cheese masala pav (2 pcs)', 'veg', NULL),
    ('Tawa Pulav', 'tawa pulav', 'veg', NULL),
    ('Cheese Tawa Pulav', 'cheese tawa pulav', 'veg', NULL),
    ('Paneer Tawa Pulav', 'paneer tawa pulav', 'veg', NULL),
    ('Mushroom Tawa Pulav', 'mushroom tawa pulav', 'veg', NULL),
    ('Extra Plain Pav', 'extra plain pav', 'veg', NULL),
    ('Extra Butter Pav', 'extra butter pav', 'veg', NULL),
    ('Veg Cheese Pizza', 'veg cheese pizza', 'veg', NULL),
    ('Margherita Pizza', 'margherita pizza', 'veg', NULL),
    ('Exotica Pizza', 'exotica pizza', 'veg', NULL),
    ('Country Feast Pizza', 'country feast pizza', 'veg', NULL),
    ('Paneer Tikka Pizza', 'paneer tikka pizza', 'veg', NULL),
    ('Veg. Extraveganza Pizza', 'veg. extraveganza pizza', 'veg', NULL),
    ('C.P.C. (Corn, Paneer, Capsicum)', 'c.p.c. (corn, paneer, capsicum)', 'veg', NULL),
    ('Veg Lover', 'veg lover', 'veg', NULL),
    ('Spicy Delight', 'spicy delight', 'veg', NULL),
    ('Veg Hawaiian', 'veg hawaiian', 'veg', NULL),
    ('Lover''s Bite', 'lover''s bite', 'veg', NULL),
    ('Veg Bonanza', 'veg bonanza', 'veg', NULL),
    ('Create Your Own Pizza (Any 5 Topping)', 'create your own pizza (any 5 topping)', 'veg', NULL),
    ('Veg Burger', 'veg burger', 'veg', NULL),
    ('Cheese Burger', 'cheese burger', 'veg', NULL),
    ('Veg Cheese Burger', 'veg cheese burger', 'veg', NULL),
    ('Veg Frankie', 'veg frankie', 'veg', NULL),
    ('Cheese Frankie', 'cheese frankie', 'veg', NULL),
    ('Paneer Frankie', 'paneer frankie', 'veg', NULL),
    ('Veg Schezwan Cheese Frankie', 'veg schezwan cheese frankie', 'veg', NULL),
    ('Penne Arrabiata (Red)', 'penne arrabiata (red)', 'veg', NULL),
    ('Penne Alfredo (White)', 'penne alfredo (white)', 'veg', NULL),
    ('Penne Alfredo (Green)', 'penne alfredo (green)', 'veg', NULL),
    ('Chinese Sizzler', 'chinese sizzler', 'veg', NULL),
    ('Oriental Sizzler', 'oriental sizzler', 'veg', NULL),
    ('Paneer Tikka Sizzler', 'paneer tikka sizzler', 'veg', NULL),
    ('Veg Thali', 'veg thali', 'veg', NULL),
    ('Deluxe Thali', 'deluxe thali', 'veg', NULL),
    ('Special Bhaji (Veg)', 'special bhaji (veg)', 'veg', NULL),
    ('Sukha Bhaji (Potato)', 'sukha bhaji (potato)', 'veg', NULL),
    ('Dal Rice', 'dal rice', 'veg', NULL),
    ('Plain Rice', 'plain rice', 'veg', NULL),
    ('Plain Dal', 'plain dal', 'veg', NULL),
    ('Half Rice', 'half rice', 'veg', NULL),
    ('Sambar (1 Plate)', 'sambar (1 plate)', 'veg', NULL),
    ('Lemon Coriandar Soup', 'lemon coriandar soup', 'veg', NULL),
    ('Tomato Soup', 'tomato soup', 'veg', NULL),
    ('Palak Soup', 'palak soup', 'veg', NULL),
    ('Corn & Spinach Soup', 'corn & spinach soup', 'veg', NULL),
    ('Cream of Tomato Soup', 'cream of tomato soup', 'veg', NULL),
    ('Cream of Palak Soup', 'cream of palak soup', 'veg', NULL),
    ('Mix Pakoda', 'mix pakoda', 'veg', NULL),
    ('Veg Pakoda', 'veg pakoda', 'veg', NULL),
    ('Paneer Pakoda (8 Pcs.)', 'paneer pakoda (8 pcs.)', 'veg', NULL),
    ('Cheese Pakoda (8 Pcs.)', 'cheese pakoda (8 pcs.)', 'veg', NULL),
    ('Hara Bhara Kabab (8 Pcs.)', 'hara bhara kabab (8 pcs.)', 'veg', NULL),
    ('Aloo Methi Tikki (8 Pcs.)', 'aloo methi tikki (8 pcs.)', 'veg', NULL),
    ('Baby Corn Pakoda (8 Pcs.)', 'baby corn pakoda (8 pcs.)', 'veg', NULL),
    ('Aloo Corn Tikki (8 Pcs.)', 'aloo corn tikki (8 pcs.)', 'veg', NULL),
    ('Cheese Corn Tikki', 'cheese corn tikki', 'veg', NULL),
    ('Aloo Tikka', 'aloo tikka', 'veg', NULL),
    ('Mushroom Tikka (8 Pcs.)', 'mushroom tikka (8 pcs.)', 'veg', NULL),
    ('Paneer Tikka (8 Pcs.)', 'paneer tikka (8 pcs.)', 'veg', NULL),
    ('Paneer Ke Sholey (8 Pcs.)', 'paneer ke sholey (8 pcs.)', 'veg', NULL),
    ('Paneer Stuff Tikka', 'paneer stuff tikka', 'veg', NULL),
    ('Cheese Mushroom Stuff Tikka', 'cheese mushroom stuff tikka', 'veg', NULL),
    ('Veg Mushroom Stuff Tikka', 'veg mushroom stuff tikka', 'veg', NULL),
    ('Kalimiri Lasoni Paneer Tikka', 'kalimiri lasoni paneer tikka', 'veg', NULL),
    ('Achari Mushroom Tikka', 'achari mushroom tikka', 'veg', NULL),
    ('Achari Paneer Tikka (8 Pcs.)', 'achari paneer tikka (8 pcs.)', 'veg', NULL),
    ('Achari Aloo Tikka', 'achari aloo tikka', 'veg', NULL),
    ('Achari Soyabean Tikka', 'achari soyabean tikka', 'veg', NULL),
    ('Tandoori Gobi', 'tandoori gobi', 'veg', NULL),
    ('Veg Seekh Kabab', 'veg seekh kabab', 'veg', NULL),
    ('Soya Chap', 'soya chap', 'veg', NULL),
    ('Peri Peri Paneer Tikka (8 Pcs.)', 'peri peri paneer tikka (8 pcs.)', 'veg', NULL),
    ('Boiled Veg', 'boiled veg', 'veg', NULL),
    ('Mix Veg', 'mix veg', 'veg', NULL),
    ('Veg Kolhapuri', 'veg kolhapuri', 'veg', NULL),
    ('Mix Veg Tawa', 'mix veg tawa', 'veg', NULL),
    ('Veg Jaipuri', 'veg jaipuri', 'veg', NULL),
    ('Veg Hydrabadi (Gree Gravy)', 'veg hydrabadi (gree gravy)', 'veg', NULL),
    ('Veg Chaap Masala', 'veg chaap masala', 'veg', NULL),
    ('Veg Jalfrazi', 'veg jalfrazi', 'veg', NULL),
    ('Veg Korma', 'veg korma', 'veg', NULL),
    ('Veg Hungama', 'veg hungama', 'veg', NULL),
    ('Veg Malvani', 'veg malvani', 'veg', NULL),
    ('Veg Kofta', 'veg kofta', 'veg', NULL),
    ('Veg Peshwari', 'veg peshwari', 'veg', NULL),
    ('Veg Banjara', 'veg banjara', 'veg', NULL),
    ('Veg Koliwada Masala', 'veg koliwada masala', 'veg', NULL),
    ('Veg Boona Masala', 'veg boona masala', 'veg', NULL),
    ('Veg Falguni', 'veg falguni', 'veg', NULL),
    ('Veg Afgani', 'veg afgani', 'veg', NULL),
    ('Veg Lahori', 'veg lahori', 'veg', NULL),
    ('Veg Majedar', 'veg majedar', 'veg', NULL),
    ('Veg Lajawab', 'veg lajawab', 'veg', NULL),
    ('Veg Chilli Milli', 'veg chilli milli', 'veg', NULL),
    ('Veg Maharaja', 'veg maharaja', 'veg', NULL),
    ('Lazzez Kofta', 'lazzez kofta', 'veg', NULL),
    ('Akbari Kofta', 'akbari kofta', 'veg', NULL),
    ('Malai Kofta', 'malai kofta', 'veg', NULL),
    ('Cheese Kofta', 'cheese kofta', 'veg', NULL),
    ('Paneer Kofta', 'paneer kofta', 'veg', NULL),
    ('Cheese Butter Masala', 'cheese butter masala', 'veg', NULL),
    ('Cheese Tomato Bhurji', 'cheese tomato bhurji', 'veg', NULL),
    ('Begum Bahar', 'begum bahar', 'veg', NULL),
    ('Beingan Bharta', 'beingan bharta', 'veg', NULL),
    ('Tomato Bharta', 'tomato bharta', 'veg', NULL),
    ('Green Peas Panner Tomato Fry', 'green peas panner tomato fry', 'veg', NULL),
    ('Green Peas Gobi', 'green peas gobi', 'veg', NULL),
    ('Green Peas Fry Masala', 'green peas fry masala', 'veg', NULL),
    ('Green Peas Palak', 'green peas palak', 'veg', NULL),
    ('Green Peas Methi', 'green peas methi', 'veg', NULL),
    ('Green Peas Masala', 'green peas masala', 'veg', NULL),
    ('Dum Aloo Punjabi', 'dum aloo punjabi', 'veg', NULL),
    ('Panner Palak', 'panner palak', 'veg', NULL),
    ('Paneer Mutter', 'paneer mutter', 'veg', NULL),
    ('Paneer Mushroom Mutter', 'paneer mushroom mutter', 'veg', NULL),
    ('Paneer Lahori', 'paneer lahori', 'veg', NULL),
    ('Paneer Bhurji', 'paneer bhurji', 'veg', NULL),
    ('Paneer Tawa', 'paneer tawa', 'veg', NULL),
    ('Paneer Chatpata', 'paneer chatpata', 'veg', NULL),
    ('Peneer Lasooni', 'peneer lasooni', 'veg', NULL),
    ('Paneer Masala', 'paneer masala', 'veg', NULL),
    ('Paneer Kolhapuri', 'paneer kolhapuri', 'veg', NULL),
    ('Paneer Butter Masala', 'paneer butter masala', 'veg', NULL),
    ('Paneer Koliwada Masala', 'paneer koliwada masala', 'veg', NULL),
    ('Paneer Tikka Masala', 'paneer tikka masala', 'veg', NULL),
    ('Paneer Malvani', 'paneer malvani', 'veg', NULL),
    ('Paneer Peshwari', 'paneer peshwari', 'veg', NULL),
    ('Bhendi Masala', 'bhendi masala', 'veg', NULL),
    ('Bhendi Fry', 'bhendi fry', 'veg', NULL),
    ('Dahi Bhendi', 'dahi bhendi', 'veg', NULL),
    ('Stuff Tomato', 'stuff tomato', 'veg', NULL),
    ('Stuff Capsicum', 'stuff capsicum', 'veg', NULL),
    ('Baby Corn Jalraize', 'baby corn jalraize', 'veg', NULL),
    ('Baby Corn Masala', 'baby corn masala', 'veg', NULL),
    ('Mushroom Tikka Masala', 'mushroom tikka masala', 'veg', NULL),
    ('Mushroom Masala', 'mushroom masala', 'veg', NULL),
    ('Mushroom Tawa', 'mushroom tawa', 'veg', NULL),
    ('Mushroom Mutter', 'mushroom mutter', 'veg', NULL),
    ('Mushroom Malvani', 'mushroom malvani', 'veg', NULL),
    ('Mushroom Green Peas Curry', 'mushroom green peas curry', 'veg', NULL),
    ('Mushroom Cheese Curry', 'mushroom cheese curry', 'veg', NULL),
    ('Mushroom Kheema', 'mushroom kheema', 'veg', NULL),
    ('Aloo Methi', 'aloo methi', 'veg', NULL),
    ('Aloo Tomato', 'aloo tomato', 'veg', NULL),
    ('Aloo Simla', 'aloo simla', 'veg', NULL),
    ('Aloo Baingan', 'aloo baingan', 'veg', NULL),
    ('Aloo Chole', 'aloo chole', 'veg', NULL),
    ('Aloo Tikka Masala', 'aloo tikka masala', 'veg', NULL),
    ('Aloo Mutter', 'aloo mutter', 'veg', NULL),
    ('Aloo Palak', 'aloo palak', 'veg', NULL),
    ('Lasooni Palak', 'lasooni palak', 'veg', NULL),
    ('Plain Palak', 'plain palak', 'veg', NULL),
    ('Makai Simla Masala', 'makai simla masala', 'veg', NULL),
    ('Hara Bhara Kabab Masala', 'hara bhara kabab masala', 'veg', NULL),
    ('Diwani Handi', 'diwani handi', 'veg', NULL),
    ('Di Bahar', 'di bahar', 'veg', NULL),
    ('Chole Bhature (2 Pcs.)', 'chole bhature (2 pcs.)', 'veg', NULL),
    ('Nargis Kofta', 'nargis kofta', 'veg', NULL),
    ('Sabji Hariyali', 'sabji hariyali', 'veg', NULL),
    ('Hanuman Special Veg.', 'hanuman special veg.', 'veg', NULL),
    ('Kadai Vegetable', 'kadai vegetable', 'veg', NULL),
    ('Handi Vegetable', 'handi vegetable', 'veg', NULL),
    ('Kadai Paneer', 'kadai paneer', 'veg', NULL),
    ('Handi Paneer', 'handi paneer', 'veg', NULL),
    ('Kadai Babycorn', 'kadai babycorn', 'veg', NULL),
    ('Handi Babycorn', 'handi babycorn', 'veg', NULL),
    ('Kadai Mushroom', 'kadai mushroom', 'veg', NULL),
    ('Handi Mushroom', 'handi mushroom', 'veg', NULL),
    ('Mushroom Malvani Sukha', 'mushroom malvani sukha', 'veg', NULL),
    ('Tawa Paneer', 'tawa paneer', 'veg', NULL),
    ('Mushroom Ghee Roast', 'mushroom ghee roast', 'veg', NULL),
    ('Paneer Malwani Koliwada', 'paneer malwani koliwada', 'veg', NULL),
    ('Ghee Roast Paneer', 'ghee roast paneer', 'veg', NULL),
    ('Mushroom Malwani Handi', 'mushroom malwani handi', 'veg', NULL),
    ('Mix Veg Malwani', 'mix veg malwani', 'veg', NULL),
    ('Kaju Malwani', 'kaju malwani', 'veg', NULL),
    ('Dal Malwani', 'dal malwani', 'veg', NULL),
    ('Kaju Curry', 'kaju curry', 'veg', NULL),
    ('Kaju Masala', 'kaju masala', 'veg', NULL),
    ('Kaju Paneer Masala', 'kaju paneer masala', 'veg', NULL),
    ('Kaju Corn Masala', 'kaju corn masala', 'veg', NULL),
    ('Veg Makhanwala', 'veg makhanwala', 'veg', NULL),
    ('Dum Aloo Kashmiri', 'dum aloo kashmiri', 'veg', NULL),
    ('Malai Methi Mutter', 'malai methi mutter', 'veg', NULL),
    ('Nav Ratan Korma', 'nav ratan korma', 'veg', NULL),
    ('Paneer Makhanwala', 'paneer makhanwala', 'veg', NULL),
    ('Paneer Korma', 'paneer korma', 'veg', NULL),
    ('Mathi Makhani Rajastani', 'mathi makhani rajastani', 'veg', NULL),
    ('Kashmiri Kofta', 'kashmiri kofta', 'veg', NULL),
    ('Dal Fry', 'dal fry', 'veg', NULL),
    ('Dal Fry Tadka', 'dal fry tadka', 'veg', NULL),
    ('Dal Lasooni', 'dal lasooni', 'veg', NULL),
    ('Dal Palak', 'dal palak', 'veg', NULL),
    ('Dal Kolhapuri', 'dal kolhapuri', 'veg', NULL),
    ('Steam Rice', 'steam rice', 'veg', NULL),
    ('Jeera Rice', 'jeera rice', 'veg', NULL),
    ('Curd Rice', 'curd rice', 'veg', NULL),
    ('Veg Pulav', 'veg pulav', 'veg', NULL),
    ('Peas Pulav', 'peas pulav', 'veg', NULL),
    ('Green Peas Mushroom Pulav', 'green peas mushroom pulav', 'veg', NULL),
    ('Cheese Pulav', 'cheese pulav', 'veg', NULL),
    ('Kaju Pulav', 'kaju pulav', 'veg', NULL),
    ('Paneer Pulav', 'paneer pulav', 'veg', NULL),
    ('Kashmiri Pulav', 'kashmiri pulav', 'veg', NULL),
    ('Hanuman Sp. Handi Pulav', 'hanuman sp. handi pulav', 'veg', NULL),
    ('Veg. Biryani', 'veg. biryani', 'veg', NULL),
    ('Dum Biryani', 'dum biryani', 'veg', NULL),
    ('Handi Biryani', 'handi biryani', 'veg', NULL),
    ('Mushroom Biryani', 'mushroom biryani', 'veg', NULL),
    ('Hyderbadi Biryani', 'hyderbadi biryani', 'veg', NULL),
    ('Paneer Biryani', 'paneer biryani', 'veg', NULL),
    ('Soyabean Biryani', 'soyabean biryani', 'veg', NULL),
    ('Hanuman Sp. Handi Biryani', 'hanuman sp. handi biryani', 'veg', NULL),
    ('Tawa Biryani', 'tawa biryani', 'veg', NULL),
    ('Palak Khichdi', 'palak khichdi', 'veg', NULL),
    ('Dal Khichdi', 'dal khichdi', 'veg', NULL),
    ('Dal Khichdi Tadka', 'dal khichdi tadka', 'veg', NULL),
    ('Tandoori Roti', 'tandoori roti', 'veg', NULL),
    ('Butter Roti', 'butter roti', 'veg', NULL),
    ('Paratha', 'paratha', 'veg', NULL),
    ('Butter Paratha', 'butter paratha', 'veg', NULL),
    ('Naan', 'naan', 'veg', NULL),
    ('Butter Naan', 'butter naan', 'veg', NULL),
    ('Kulcha', 'kulcha', 'veg', NULL),
    ('Butter Kulcha', 'butter kulcha', 'veg', NULL),
    ('Cheese Naan', 'cheese naan', 'veg', NULL),
    ('Kashmiri Naan', 'kashmiri naan', 'veg', NULL),
    ('Cheese Garlic Naan', 'cheese garlic naan', 'veg', NULL),
    ('Garlic Naan', 'garlic naan', 'veg', NULL),
    ('Ginger Naan', 'ginger naan', 'veg', NULL),
    ('Veg Stuff Paratha', 'veg stuff paratha', 'veg', NULL),
    ('Aloo Paratha', 'aloo paratha', 'veg', NULL),
    ('Methi Paratha', 'methi paratha', 'veg', NULL),
    ('Onion Paratha', 'onion paratha', 'veg', NULL),
    ('Meethi Roti', 'meethi roti', 'veg', NULL),
    ('Pudina Roti', 'pudina roti', 'veg', NULL),
    ('Messi Roti', 'messi roti', 'veg', NULL),
    ('Stuff Kulcha', 'stuff kulcha', 'veg', NULL),
    ('Bhatura (Single)', 'bhatura (single)', 'veg', NULL),
    ('Puri Plate', 'puri plate', 'veg', NULL),
    ('Roti Ki Tokri (Assorted)', 'roti ki tokri (assorted)', 'veg', NULL),
    ('Chapati', 'chapati', 'veg', NULL),
    ('Veg Clear Soup', 'veg clear soup', 'veg', NULL),
    ('Cream of Veg Soup', 'cream of veg soup', 'veg', NULL),
    ('Veg Noodle Soup', 'veg noodle soup', 'veg', NULL),
    ('Manchow Soup', 'manchow soup', 'veg', NULL),
    ('French Onion Soup', 'french onion soup', 'veg', NULL),
    ('Mushroom Soup', 'mushroom soup', 'veg', NULL),
    ('Cream of Mushroom Soup', 'cream of mushroom soup', 'veg', NULL),
    ('Sweet Corn Soup', 'sweet corn soup', 'veg', NULL),
    ('Hot N Sour Soup', 'hot n sour soup', 'veg', NULL),
    ('Tom Yum Soup (Thai)', 'tom yum soup (thai)', 'veg', NULL),
    ('Oriental Soup', 'oriental soup', 'veg', NULL),
    ('Lung Fung Soup', 'lung fung soup', 'veg', NULL),
    ('Idli Chilly', 'idli chilly', 'veg', NULL),
    ('Veg Crispy', 'veg crispy', 'veg', NULL),
    ('Veg Manchurian', 'veg manchurian', 'veg', NULL),
    ('Crispy Chilly Potato', 'crispy chilly potato', 'veg', NULL),
    ('Veg Chilly', 'veg chilly', 'veg', NULL),
    ('Veg 65', 'veg 65', 'veg', NULL),
    ('Veg Schezwan Finger', 'veg schezwan finger', 'veg', NULL),
    ('Chinese Bhel', 'chinese bhel', 'veg', NULL),
    ('Veg Gold Coin', 'veg gold coin', 'veg', NULL),
    ('Paneer Chilly', 'paneer chilly', 'veg', NULL),
    ('Paneer Gravy', 'paneer gravy', 'veg', NULL),
    ('Paneer 65', 'paneer 65', 'veg', NULL),
    ('Paneer Satey', 'paneer satey', 'veg', NULL),
    ('Paneer Crispy', 'paneer crispy', 'veg', NULL),
    ('Paneer Hunan', 'paneer hunan', 'veg', NULL),
    ('Paneer Teriyaki', 'paneer teriyaki', 'veg', NULL),
    ('Panner Schezwan Finger', 'panner schezwan finger', 'veg', NULL),
    ('Paneer Salt n Pepper', 'paneer salt n pepper', 'veg', NULL),
    ('Veg Spring Roll', 'veg spring roll', 'veg', NULL),
    ('Panner Spring Roll', 'panner spring roll', 'veg', NULL),
    ('Paneer Mushroom Spring Roll', 'paneer mushroom spring roll', 'veg', NULL),
    ('Panner in Garlic Sauce', 'panner in garlic sauce', 'veg', NULL),
    ('Panner Burnt Garlic', 'panner burnt garlic', 'veg', NULL),
    ('Panner Manchurian', 'panner manchurian', 'veg', NULL),
    ('Cheese Onion Roll (8 Pcs)', 'cheese onion roll (8 pcs)', 'veg', NULL),
    ('Cheese Chilly Roll (8 Pcs)', 'cheese chilly roll (8 pcs)', 'veg', NULL),
    ('Mushroom Chilly', 'mushroom chilly', 'veg', NULL),
    ('Mushroom Manchurian', 'mushroom manchurian', 'veg', NULL),
    ('Mushroom Salt n Pepper', 'mushroom salt n pepper', 'veg', NULL),
    ('Bobycorn Salt n Pepper', 'bobycorn salt n pepper', 'veg', NULL),
    ('Babycorn Manchurian', 'babycorn manchurian', 'veg', NULL),
    ('Babycorn Chilly', 'babycorn chilly', 'veg', NULL),
    ('Paneer in Barbeque Sauce', 'paneer in barbeque sauce', 'veg', NULL),
    ('Pepper Panner', 'pepper panner', 'veg', NULL),
    ('Babycorn Mushroom Salt n Pepper', 'babycorn mushroom salt n pepper', 'veg', NULL),
    ('Stuffed Barbeque Mushroom', 'stuffed barbeque mushroom', 'veg', NULL),
    ('Soyabean Manchurian', 'soyabean manchurian', 'veg', NULL),
    ('Soyabean Chilly', 'soyabean chilly', 'veg', NULL),
    ('Sesame Toast', 'sesame toast', 'veg', NULL),
    ('Mix Veg in Green Sauce', 'mix veg in green sauce', 'veg', NULL),
    ('Veg Schezwan', 'veg schezwan', 'veg', NULL),
    ('Veg Hongkong', 'veg hongkong', 'veg', NULL),
    ('Veg Schezwan Ball', 'veg schezwan ball', 'veg', NULL),
    ('Paneer Schezwan (Gravy)', 'paneer schezwan (gravy)', 'veg', NULL),
    ('Babycorn Mushroom in Green Sauce', 'babycorn mushroom in green sauce', 'veg', NULL),
    ('Soyabean Manchurian (Gravy)', 'soyabean manchurian (gravy)', 'veg', NULL),
    ('Veg Manchurian (Gravy)', 'veg manchurian (gravy)', 'veg', NULL),
    ('Veg Sweet n Sour', 'veg sweet n sour', 'veg', NULL),
    ('Paneer in Garlic Sauce', 'paneer in garlic sauce', 'veg', NULL),
    ('Paneer Chilly (Gravy)', 'paneer chilly (gravy)', 'veg', NULL),
    ('Babycorn Manchurian (Gravy)', 'babycorn manchurian (gravy)', 'veg', NULL),
    ('Babycorn Chilly (Gravy)', 'babycorn chilly (gravy)', 'veg', NULL),
    ('Gobi Manchurian (Gravy)', 'gobi manchurian (gravy)', 'veg', NULL),
    ('Thai Curry (Red & Green)', 'thai curry (red & green)', 'veg', NULL),
    ('Veg Hakka Noodles', 'veg hakka noodles', 'veg', NULL),
    ('Veg Schezwan Noodles', 'veg schezwan noodles', 'veg', NULL),
    ('Veg Singapore Noodles', 'veg singapore noodles', 'veg', NULL),
    ('Veg Hongkong Noodles', 'veg hongkong noodles', 'veg', NULL),
    ('Veg Thai Basil Noodles', 'veg thai basil noodles', 'veg', NULL),
    ('Veg Chowmein', 'veg chowmein', 'veg', NULL),
    ('American Chopsuey', 'american chopsuey', 'veg', NULL),
    ('Garlic Pepper Noodles', 'garlic pepper noodles', 'veg', NULL),
    ('Burnt Garlic Noodles', 'burnt garlic noodles', 'veg', NULL),
    ('Paneer Noodles', 'paneer noodles', 'veg', NULL),
    ('Triple Schezwan Noodles', 'triple schezwan noodles', 'veg', NULL),
    ('Lemon Rice', 'lemon rice', 'veg', NULL),
    ('Fried Rice', 'fried rice', 'veg', NULL),
    ('Jeera Fried Rice', 'jeera fried rice', 'veg', NULL),
    ('Mix Fried Rice', 'mix fried rice', 'veg', NULL),
    ('Schezwan Fied Rice', 'schezwan fied rice', 'veg', NULL),
    ('Paneer Fied Rice', 'paneer fied rice', 'veg', NULL),
    ('Singapore Fried Rice', 'singapore fried rice', 'veg', NULL),
    ('Hongkong Fried Rice', 'hongkong fried rice', 'veg', NULL),
    ('Mushroom Fried Rice', 'mushroom fried rice', 'veg', NULL),
    ('Ginger Garlic Fried Rice', 'ginger garlic fried rice', 'veg', NULL),
    ('Cantonese Fried Rice', 'cantonese fried rice', 'veg', NULL),
    ('Triple Schezwan Fried Rice', 'triple schezwan fried rice', 'veg', NULL),
    ('Burnt Garlic Fried Rice', 'burnt garlic fried rice', 'veg', NULL),
    ('Veg Stewed Rice', 'veg stewed rice', 'veg', NULL),
    ('Manchurian Rice Combination', 'manchurian rice combination', 'veg', NULL),
    ('Pot Rice', 'pot rice', 'veg', NULL),
    ('Veg Sandwich', 'veg sandwich', 'veg', NULL),
    ('Veg Cheese Sandwich', 'veg cheese sandwich', 'veg', NULL),
    ('Tomato Omlet Sandwich', 'tomato omlet sandwich', 'egg', 'egg'),
    ('Club Sandwich', 'club sandwich', 'veg', NULL),
    ('Paneer Sandwich', 'paneer sandwich', 'veg', NULL),
    ('Paneer Tikka Grill', 'paneer tikka grill', 'veg', NULL),
    ('Bread Butter', 'bread butter', 'veg', NULL),
    ('Bread Jam', 'bread jam', 'veg', NULL),
    ('Chilly Cheese Grill Sandwich', 'chilly cheese grill sandwich', 'veg', NULL),
    ('Plain Cheese Sandwich', 'plain cheese sandwich', 'veg', NULL),
    ('Cheese Chilly Toast', 'cheese chilly toast', 'veg', NULL),
    ('Cheese Garlic Toast', 'cheese garlic toast', 'veg', NULL)
),
new_dishes AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
  SELECT nextval('khaustan_onboarding_id_seq'), cd.canonical_name, cd.normalized_name, cd.food_classification_code, pt.protein_type_id
  FROM candidate_dishes cd
  LEFT JOIN protein_type pt ON pt.code = cd.protein_code
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish existing WHERE existing.normalized_name = cd.normalized_name)
  RETURNING canonical_dish_id, canonical_name, normalized_name
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_onboarding_id_seq'), nd.canonical_dish_id, 'en', nd.canonical_name, nd.normalized_name, 'primary'
FROM new_dishes nd;

-- =============================================================================
-- Menu items: one chained statement per distinct printed menu line.
-- Each chain now also (a) tags split_group_key when this line was one
-- printed line expanded into two menu_item rows, (b) adds
-- menu_item_availability rows for items with a stated time window, and
-- (c) records menu_item_price_source alongside menu_item_source.
-- =============================================================================

-- Source: docx, "SNACKS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Upma (Mor. 8.00 to 11.00 am)', 'upma (mor. 8.00 to 11.00 am)', 'SNACKS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'upma (mor. 8.00 to 11.00 am)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '08:00', '11:00'
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "SNACKS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Sheera (Mor. 8.00 to 11.00 am)', 'sheera (mor. 8.00 to 11.00 am)', 'SNACKS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sheera (mor. 8.00 to 11.00 am)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '08:00', '11:00'
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "SNACKS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Steam Idli', 'steam idli', 'SNACKS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'steam idli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SNACKS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Butter Idli', 'butter idli', 'SNACKS', 'veg', 'split-butter-idli-fried-idli', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter idli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "SNACKS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Fried Idli', 'fried idli', 'SNACKS', 'veg', 'split-butter-idli-fried-idli', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fried idli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "SNACKS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dahi Idli', 'dahi idli', 'SNACKS', 'veg', 'split-dahi-idli-dahi-vada', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dahi idli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "SNACKS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dahi Vada', 'dahi vada', 'SNACKS', 'veg', 'split-dahi-idli-dahi-vada', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dahi vada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "SNACKS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Medu Vada', 'medu vada', 'SNACKS', 'veg', 'split-medu-vada-idli-vada', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'medu vada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "SNACKS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Idli Vada', 'idli vada', 'SNACKS', 'veg', 'split-medu-vada-idli-vada', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'idli vada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "SNACKS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Batata Vada', 'batata vada', 'SNACKS', 'veg', 'split-batata-vada-mix-vada', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'batata vada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "SNACKS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mix Vada', 'mix vada', 'SNACKS', 'veg', 'split-batata-vada-mix-vada', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix vada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "SNACKS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Misal Pav', 'misal pav', 'SNACKS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'misal pav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SNACKS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Puri Bhaji', 'puri bhaji', 'SNACKS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'puri bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "FASTING (UPVAS)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Finger Chips', 'finger chips', 'FASTING (UPVAS)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'finger chips'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "FASTING (UPVAS)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Sabudana Vada', 'sabudana vada', 'FASTING (UPVAS)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sabudana vada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "FASTING (UPVAS)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Sweet Kachori', 'sweet kachori', 'FASTING (UPVAS)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet kachori'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Sada Dosa', 'sada dosa', 'DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Rava Dosa', 'rava dosa', 'DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rava dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Masala Dosa', 'masala dosa', 'DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Rava Masal Dosa', 'rava masal dosa', 'DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rava masal dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mysore Sada Dosa', 'mysore sada dosa', 'DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mysore sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mysore Masala Dosa', 'mysore masala dosa', 'DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mysore masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paper Sada Dosa', 'paper sada dosa', 'DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paper sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paper Masal Dosa', 'paper masal dosa', 'DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paper masal dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mysore Rava Dosa', 'mysore rava dosa', 'DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mysore rava dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mysore Rava Masala Dosa', 'mysore rava masala dosa', 'DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mysore rava masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "UTTAPPAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Plain Uttappam', 'plain uttappam', 'UTTAPPAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'plain uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "UTTAPPAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Onion Uttappam', 'onion uttappam', 'UTTAPPAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'onion uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "UTTAPPAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Tomato Uttappam', 'tomato uttappam', 'UTTAPPAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "UTTAPPAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Masala Uttappam', 'masala uttappam', 'UTTAPPAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'masala uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "UTTAPPAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Tomato Omlet', 'tomato omlet', 'UTTAPPAM', 'egg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'tomato omlet' AND pt.code = 'egg'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.60, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "UTTAPPAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Tomato Omlet', 'cheese tomato omlet', 'UTTAPPAM', 'egg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'cheese tomato omlet' AND pt.code = 'egg'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.60, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "UTTAPPAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Tomato Uttappam', 'cheese tomato uttappam', 'UTTAPPAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese tomato uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "UTTAPPAM" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Onion Uttappam', 'cheese onion uttappam', 'UTTAPPAM', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese onion uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Spring Rol Dosa', 'spring rol dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'spring rol dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Palak Dosa', 'palak dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Palak Masala Dosa', 'palak masala dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Dosa', 'cheese dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Masala Dosa', 'cheese masala dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Schezwan Sada Dosa', 'schezwan sada dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'schezwan sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Schezwan Masala Dosa', 'schezwan masala dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'schezwan masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Benne Dosa', 'benne dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'benne dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Benne Masala Dosa', 'benne masala dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'benne masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Pav Bhaji', 'pav bhaji', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Pav Bhaji', 'cheese pav bhaji', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Khada Pav Bhaji', 'khada pav bhaji', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'khada pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Khada Pav Bhaji', 'cheese khada pav bhaji', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese khada pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Pav Bhaji', 'mushroom pav bhaji', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Pav Bhaji', 'paneer pav bhaji', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Jain Pav Bhaji', 'jain pav bhaji', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jain pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Jain Cheese Pav Bhaji', 'jain cheese pav bhaji', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jain cheese pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Only Bhaji', 'only bhaji', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'only bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Masala Pav (2 Pcs)', 'masala pav (2 pcs)', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'masala pav (2 pcs)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Masala Pav (2 Pcs)', 'cheese masala pav (2 pcs)', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese masala pav (2 pcs)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Tawa Pulav', 'tawa pulav', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tawa pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Tawa Pulav', 'cheese tawa pulav', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese tawa pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Tawa Pulav', 'paneer tawa pulav', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'split-paneer-mushroom-tawa-pulav', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tawa pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Tawa Pulav', 'mushroom tawa pulav', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'split-paneer-mushroom-tawa-pulav', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom tawa pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Extra Plain Pav', 'extra plain pav', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'split-extra-plain-pav-butter-pav', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'extra plain pav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 7.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PAV BHAJI (AFTER 12.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Extra Butter Pav', 'extra butter pav', 'PAV BHAJI (AFTER 12.00 PM)', 'veg', 'split-extra-plain-pav-butter-pav', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'extra butter pav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 16.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '12:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Cheese Pizza', 'veg cheese pizza', 'PIZZA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg cheese pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Margherita Pizza', 'margherita pizza', 'PIZZA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'margherita pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Exotica Pizza', 'exotica pizza', 'PIZZA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'exotica pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Country Feast Pizza', 'country feast pizza', 'PIZZA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'country feast pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Tikka Pizza', 'paneer tikka pizza', 'PIZZA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg. Extraveganza Pizza', 'veg. extraveganza pizza', 'PIZZA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. extraveganza pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'C.P.C. (Corn, Paneer, Capsicum)', 'c.p.c. (corn, paneer, capsicum)', 'PIZZA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'c.p.c. (corn, paneer, capsicum)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Lover', 'veg lover', 'PIZZA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg lover'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Spicy Delight', 'spicy delight', 'PIZZA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'spicy delight'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Hawaiian', 'veg hawaiian', 'PIZZA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg hawaiian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Lover''s Bite', 'lover''s bite', 'PIZZA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'lover''s bite'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Bonanza', 'veg bonanza', 'PIZZA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg bonanza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PIZZA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Create Your Own Pizza (Any 5 Topping)', 'create your own pizza (any 5 topping)', 'PIZZA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'create your own pizza (any 5 topping)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "BURGER / FRANKIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Burger', 'veg burger', 'BURGER / FRANKIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "BURGER / FRANKIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Burger', 'cheese burger', 'BURGER / FRANKIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "BURGER / FRANKIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Cheese Burger', 'veg cheese burger', 'BURGER / FRANKIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg cheese burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "BURGER / FRANKIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Frankie', 'veg frankie', 'BURGER / FRANKIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg frankie'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "BURGER / FRANKIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Frankie', 'cheese frankie', 'BURGER / FRANKIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese frankie'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "BURGER / FRANKIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Frankie', 'paneer frankie', 'BURGER / FRANKIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer frankie'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "BURGER / FRANKIES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Schezwan Cheese Frankie', 'veg schezwan cheese frankie', 'BURGER / FRANKIES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg schezwan cheese frankie'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PASTA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Penne Arrabiata (Red)', 'penne arrabiata (red)', 'PASTA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'penne arrabiata (red)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PASTA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Penne Alfredo (White)', 'penne alfredo (white)', 'PASTA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'penne alfredo (white)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "PASTA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Penne Alfredo (Green)', 'penne alfredo (green)', 'PASTA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'penne alfredo (green)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SIZZLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Chinese Sizzler', 'chinese sizzler', 'SIZZLERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chinese sizzler'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SIZZLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Oriental Sizzler', 'oriental sizzler', 'SIZZLERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'oriental sizzler'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SIZZLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Tikka Sizzler', 'paneer tikka sizzler', 'SIZZLERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka sizzler'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "LUNCH (11.00 AM TO 3.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Thali', 'veg thali', 'LUNCH (11.00 AM TO 3.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg thali'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '11:00', '15:00'
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "LUNCH (11.00 AM TO 3.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Deluxe Thali', 'deluxe thali', 'LUNCH (11.00 AM TO 3.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'deluxe thali'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '11:00', '15:00'
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "LUNCH (11.00 AM TO 3.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Special Bhaji (Veg)', 'special bhaji (veg)', 'LUNCH (11.00 AM TO 3.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'special bhaji (veg)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '11:00', '15:00'
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "LUNCH (11.00 AM TO 3.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Sukha Bhaji (Potato)', 'sukha bhaji (potato)', 'LUNCH (11.00 AM TO 3.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sukha bhaji (potato)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '11:00', '15:00'
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "LUNCH (11.00 AM TO 3.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dal Rice', 'dal rice', 'LUNCH (11.00 AM TO 3.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '11:00', '15:00'
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "LUNCH (11.00 AM TO 3.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Plain Rice', 'plain rice', 'LUNCH (11.00 AM TO 3.00 PM)', 'veg', 'split-plain-rice-plain-dal', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'plain rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '11:00', '15:00'
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "LUNCH (11.00 AM TO 3.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Plain Dal', 'plain dal', 'LUNCH (11.00 AM TO 3.00 PM)', 'veg', 'split-plain-rice-plain-dal', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'plain dal'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '11:00', '15:00'
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "LUNCH (11.00 AM TO 3.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Half Rice', 'half rice', 'LUNCH (11.00 AM TO 3.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'half rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '11:00', '15:00'
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "LUNCH (11.00 AM TO 3.00 PM)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Sambar (1 Plate)', 'sambar (1 plate)', 'LUNCH (11.00 AM TO 3.00 PM)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sambar (1 plate)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
),
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT nextval('khaustan_availability_id_seq'), new_item.menu_item_id, NULL, '11:00', '15:00'
FROM new_item, price_src
LIMIT 1;

-- Source: docx, "SOUP (INDIAN)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Lemon Coriandar Soup', 'lemon coriandar soup', 'SOUP (INDIAN)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'lemon coriandar soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SOUP (INDIAN)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Tomato Soup', 'tomato soup', 'SOUP (INDIAN)', 'veg', 'split-tomato-soup-palak-soup', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "SOUP (INDIAN)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Palak Soup', 'palak soup', 'SOUP (INDIAN)', 'veg', 'split-tomato-soup-palak-soup', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "SOUP (INDIAN)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Corn & Spinach Soup', 'corn & spinach soup', 'SOUP (INDIAN)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'corn & spinach soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SOUP (INDIAN)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cream of Tomato Soup', 'cream of tomato soup', 'SOUP (INDIAN)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cream of tomato soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SOUP (INDIAN)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cream of Palak Soup', 'cream of palak soup', 'SOUP (INDIAN)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cream of palak soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN STARTERS (KADAI)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mix Pakoda', 'mix pakoda', 'INDIAN STARTERS (KADAI)', 'veg', 'split-mix-pakoda-veg-pakoda', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix pakoda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "INDIAN STARTERS (KADAI)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Pakoda', 'veg pakoda', 'INDIAN STARTERS (KADAI)', 'veg', 'split-mix-pakoda-veg-pakoda', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg pakoda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "INDIAN STARTERS (KADAI)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Pakoda (8 Pcs.)', 'paneer pakoda (8 pcs.)', 'INDIAN STARTERS (KADAI)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer pakoda (8 pcs.)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN STARTERS (KADAI)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Pakoda (8 Pcs.)', 'cheese pakoda (8 pcs.)', 'INDIAN STARTERS (KADAI)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese pakoda (8 pcs.)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN STARTERS (KADAI)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Hara Bhara Kabab (8 Pcs.)', 'hara bhara kabab (8 pcs.)', 'INDIAN STARTERS (KADAI)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hara bhara kabab (8 pcs.)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN STARTERS (KADAI)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Aloo Methi Tikki (8 Pcs.)', 'aloo methi tikki (8 pcs.)', 'INDIAN STARTERS (KADAI)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo methi tikki (8 pcs.)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN STARTERS (KADAI)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Baby Corn Pakoda (8 Pcs.)', 'baby corn pakoda (8 pcs.)', 'INDIAN STARTERS (KADAI)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn pakoda (8 pcs.)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN STARTERS (KADAI)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Aloo Corn Tikki (8 Pcs.)', 'aloo corn tikki (8 pcs.)', 'INDIAN STARTERS (KADAI)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo corn tikki (8 pcs.)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN STARTERS (KADAI)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Corn Tikki', 'cheese corn tikki', 'INDIAN STARTERS (KADAI)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese corn tikki'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Aloo Tikka', 'aloo tikka', 'STARTERS (TANDOOR)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo tikka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Tikka (8 Pcs.)', 'mushroom tikka (8 pcs.)', 'STARTERS (TANDOOR)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom tikka (8 pcs.)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Tikka (8 Pcs.)', 'paneer tikka (8 pcs.)', 'STARTERS (TANDOOR)', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka (8 pcs.)'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES ('Yellow', TRUE), ('Red', FALSE)) AS x(variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review'
  FROM new_variants nv JOIN (VALUES ('Yellow', 250.00), ('Red', 250.00)) AS x(variant_name, price_amount)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_prices, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Ke Sholey (8 Pcs.)', 'paneer ke sholey (8 pcs.)', 'STARTERS (TANDOOR)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer ke sholey (8 pcs.)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Stuff Tikka', 'paneer stuff tikka', 'STARTERS (TANDOOR)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer stuff tikka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Mushroom Stuff Tikka', 'cheese mushroom stuff tikka', 'STARTERS (TANDOOR)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese mushroom stuff tikka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Mushroom Stuff Tikka', 'veg mushroom stuff tikka', 'STARTERS (TANDOOR)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg mushroom stuff tikka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kalimiri Lasoni Paneer Tikka', 'kalimiri lasoni paneer tikka', 'STARTERS (TANDOOR)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kalimiri lasoni paneer tikka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Achari Mushroom Tikka', 'achari mushroom tikka', 'STARTERS (TANDOOR)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'achari mushroom tikka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Achari Paneer Tikka (8 Pcs.)', 'achari paneer tikka (8 pcs.)', 'STARTERS (TANDOOR)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'achari paneer tikka (8 pcs.)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Achari Aloo Tikka', 'achari aloo tikka', 'STARTERS (TANDOOR)', 'veg', 'split-achari-aloo-soyabean-tikka', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'achari aloo tikka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Achari Soyabean Tikka', 'achari soyabean tikka', 'STARTERS (TANDOOR)', 'veg', 'split-achari-aloo-soyabean-tikka', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'achari soyabean tikka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.70, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.70 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Tandoori Gobi', 'tandoori gobi', 'STARTERS (TANDOOR)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tandoori gobi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Seekh Kabab', 'veg seekh kabab', 'STARTERS (TANDOOR)', 'veg', 'split-veg-seekh-kabab-soya-chap', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg seekh kabab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Soya Chap', 'soya chap', 'STARTERS (TANDOOR)', 'veg', 'split-veg-seekh-kabab-soya-chap', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'soya chap'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "STARTERS (TANDOOR)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Peri Peri Paneer Tikka (8 Pcs.)', 'peri peri paneer tikka (8 pcs.)', 'STARTERS (TANDOOR)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'peri peri paneer tikka (8 pcs.)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Boiled Veg', 'boiled veg', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'boiled veg'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mix Veg', 'mix veg', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix veg'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Kolhapuri', 'veg kolhapuri', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg kolhapuri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mix Veg Tawa', 'mix veg tawa', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix veg tawa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Jaipuri', 'veg jaipuri', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg jaipuri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Hydrabadi (Gree Gravy)', 'veg hydrabadi (gree gravy)', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg hydrabadi (gree gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Chaap Masala', 'veg chaap masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg chaap masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 255.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Jalfrazi', 'veg jalfrazi', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg jalfrazi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 255.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Korma', 'veg korma', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg korma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 215.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Hungama', 'veg hungama', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg hungama'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Malvani', 'veg malvani', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg malvani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Kofta', 'veg kofta', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Peshwari', 'veg peshwari', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg peshwari'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Banjara', 'veg banjara', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg banjara'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Koliwada Masala', 'veg koliwada masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg koliwada masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Boona Masala', 'veg boona masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg boona masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Falguni', 'veg falguni', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg falguni'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Afgani', 'veg afgani', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg afgani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Lahori', 'veg lahori', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg lahori'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Majedar', 'veg majedar', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg majedar'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Lajawab', 'veg lajawab', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg lajawab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Chilli Milli', 'veg chilli milli', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg chilli milli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Maharaja', 'veg maharaja', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg maharaja'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Lazzez Kofta', 'lazzez kofta', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'lazzez kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 295.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Akbari Kofta', 'akbari kofta', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'akbari kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 295.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Malai Kofta', 'malai kofta', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'malai kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Kofta', 'cheese kofta', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Kofta', 'paneer kofta', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Butter Masala', 'cheese butter masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese butter masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Tomato Bhurji', 'cheese tomato bhurji', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese tomato bhurji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Begum Bahar', 'begum bahar', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'begum bahar'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Beingan Bharta', 'beingan bharta', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'beingan bharta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Tomato Bharta', 'tomato bharta', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato bharta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Green Peas Panner Tomato Fry', 'green peas panner tomato fry', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas panner tomato fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Green Peas Gobi', 'green peas gobi', 'INDIAN MAIN COURSE', 'veg', 'split-green-peas-gobi-fry-masala', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas gobi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 195.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.50, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.50 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Green Peas Fry Masala', 'green peas fry masala', 'INDIAN MAIN COURSE', 'veg', 'split-green-peas-gobi-fry-masala', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas fry masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 195.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.50, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.50 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Green Peas Palak', 'green peas palak', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 195.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Green Peas Methi', 'green peas methi', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas methi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Green Peas Masala', 'green peas masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dum Aloo Punjabi', 'dum aloo punjabi', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dum aloo punjabi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Panner Palak', 'panner palak', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'panner palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Mutter', 'paneer mutter', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Mushroom Mutter', 'paneer mushroom mutter', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer mushroom mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Lahori', 'paneer lahori', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer lahori'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Bhurji', 'paneer bhurji', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer bhurji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Tawa', 'paneer tawa', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tawa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Chatpata', 'paneer chatpata', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chatpata'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Peneer Lasooni', 'peneer lasooni', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'peneer lasooni'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Masala', 'paneer masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Kolhapuri', 'paneer kolhapuri', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kolhapuri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Butter Masala', 'paneer butter masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer butter masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Koliwada Masala', 'paneer koliwada masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer koliwada masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Tikka Masala', 'paneer tikka masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Malvani', 'paneer malvani', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer malvani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Peshwari', 'paneer peshwari', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer peshwari'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Bhendi Masala', 'bhendi masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bhendi masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Bhendi Fry', 'bhendi fry', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bhendi fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dahi Bhendi', 'dahi bhendi', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dahi bhendi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Stuff Tomato', 'stuff tomato', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'stuff tomato'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Stuff Capsicum', 'stuff capsicum', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'stuff capsicum'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Baby Corn Jalraize', 'baby corn jalraize', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn jalraize'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Baby Corn Masala', 'baby corn masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Tikka Masala', 'mushroom tikka masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom tikka masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Masala', 'mushroom masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Tawa', 'mushroom tawa', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom tawa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Mutter', 'mushroom mutter', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Malvani', 'mushroom malvani', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom malvani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Green Peas Curry', 'mushroom green peas curry', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom green peas curry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 235.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Cheese Curry', 'mushroom cheese curry', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom cheese curry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Kheema', 'mushroom kheema', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom kheema'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 235.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Aloo Methi', 'aloo methi', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo methi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Aloo Tomato', 'aloo tomato', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo tomato'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Aloo Simla', 'aloo simla', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo simla'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Aloo Baingan', 'aloo baingan', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo baingan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Aloo Chole', 'aloo chole', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo chole'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Aloo Tikka Masala', 'aloo tikka masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo tikka masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Aloo Mutter', 'aloo mutter', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Aloo Palak', 'aloo palak', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Lasooni Palak', 'lasooni palak', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'lasooni palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Plain Palak', 'plain palak', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'plain palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Makai Simla Masala', 'makai simla masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'makai simla masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Hara Bhara Kabab Masala', 'hara bhara kabab masala', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hara bhara kabab masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Diwani Handi', 'diwani handi', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'diwani handi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Di Bahar', 'di bahar', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'di bahar'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 285.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Chole Bhature (2 Pcs.)', 'chole bhature (2 pcs.)', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chole bhature (2 pcs.)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Nargis Kofta', 'nargis kofta', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nargis kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Sabji Hariyali', 'sabji hariyali', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sabji hariyali'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Hanuman Special Veg.', 'hanuman special veg.', 'INDIAN MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hanuman special veg.'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "KADAI AUR HANDI KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kadai Vegetable', 'kadai vegetable', 'KADAI AUR HANDI KA KAMAL', 'veg', 'split-kadai-handi-vegetable', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kadai vegetable'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "KADAI AUR HANDI KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Handi Vegetable', 'handi vegetable', 'KADAI AUR HANDI KA KAMAL', 'veg', 'split-kadai-handi-vegetable', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'handi vegetable'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "KADAI AUR HANDI KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kadai Paneer', 'kadai paneer', 'KADAI AUR HANDI KA KAMAL', 'veg', 'split-kadai-handi-paneer', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kadai paneer'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "KADAI AUR HANDI KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Handi Paneer', 'handi paneer', 'KADAI AUR HANDI KA KAMAL', 'veg', 'split-kadai-handi-paneer', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'handi paneer'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "KADAI AUR HANDI KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kadai Babycorn', 'kadai babycorn', 'KADAI AUR HANDI KA KAMAL', 'veg', 'split-kadai-handi-babycorn', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kadai babycorn'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "KADAI AUR HANDI KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Handi Babycorn', 'handi babycorn', 'KADAI AUR HANDI KA KAMAL', 'veg', 'split-kadai-handi-babycorn', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'handi babycorn'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "KADAI AUR HANDI KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kadai Mushroom', 'kadai mushroom', 'KADAI AUR HANDI KA KAMAL', 'veg', 'split-kadai-handi-mushroom', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kadai mushroom'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "KADAI AUR HANDI KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Handi Mushroom', 'handi mushroom', 'KADAI AUR HANDI KA KAMAL', 'veg', 'split-kadai-handi-mushroom', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'handi mushroom'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "MALWANI MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Malvani Sukha', 'mushroom malvani sukha', 'MALWANI MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom malvani sukha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "MALWANI MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Tawa Paneer', 'tawa paneer', 'MALWANI MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tawa paneer'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "MALWANI MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Ghee Roast', 'mushroom ghee roast', 'MALWANI MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom ghee roast'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "MALWANI MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Malwani Koliwada', 'paneer malwani koliwada', 'MALWANI MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer malwani koliwada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "MALWANI MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Ghee Roast Paneer', 'ghee roast paneer', 'MALWANI MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ghee roast paneer'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "MALWANI MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Malwani Handi', 'mushroom malwani handi', 'MALWANI MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom malwani handi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "MALWANI MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mix Veg Malwani', 'mix veg malwani', 'MALWANI MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix veg malwani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "MALWANI MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kaju Malwani', 'kaju malwani', 'MALWANI MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju malwani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "MALWANI MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dal Malwani', 'dal malwani', 'MALWANI MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal malwani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "KAJU SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kaju Curry', 'kaju curry', 'KAJU SPECIAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju curry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "KAJU SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kaju Masala', 'kaju masala', 'KAJU SPECIAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "KAJU SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kaju Paneer Masala', 'kaju paneer masala', 'KAJU SPECIAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju paneer masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "KAJU SPECIAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kaju Corn Masala', 'kaju corn masala', 'KAJU SPECIAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju corn masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "VEG (SWEET)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Makhanwala', 'veg makhanwala', 'VEG (SWEET)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg makhanwala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 215.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "VEG (SWEET)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dum Aloo Kashmiri', 'dum aloo kashmiri', 'VEG (SWEET)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dum aloo kashmiri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "VEG (SWEET)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Malai Methi Mutter', 'malai methi mutter', 'VEG (SWEET)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'malai methi mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "VEG (SWEET)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Malai Kofta', 'malai kofta', 'VEG (SWEET)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'malai kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "VEG (SWEET)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Nav Ratan Korma', 'nav ratan korma', 'VEG (SWEET)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nav ratan korma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "VEG (SWEET)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Makhanwala', 'paneer makhanwala', 'VEG (SWEET)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer makhanwala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "VEG (SWEET)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Korma', 'paneer korma', 'VEG (SWEET)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer korma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "VEG (SWEET)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mathi Makhani Rajastani', 'mathi makhani rajastani', 'VEG (SWEET)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mathi makhani rajastani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "VEG (SWEET)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kashmiri Kofta', 'kashmiri kofta', 'VEG (SWEET)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kashmiri kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dal Fry', 'dal fry', 'DAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dal Fry Tadka', 'dal fry tadka', 'DAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal fry tadka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dal Lasooni', 'dal lasooni', 'DAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal lasooni'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dal Palak', 'dal palak', 'DAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "DAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dal Kolhapuri', 'dal kolhapuri', 'DAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal kolhapuri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Steam Rice', 'steam rice', 'RICE', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'steam rice'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES ('Full', TRUE), ('Half', FALSE)) AS x(variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review'
  FROM new_variants nv JOIN (VALUES ('Full', 140.00), ('Half', 100.00)) AS x(variant_name, price_amount)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.75, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.75 FROM new_prices, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Jeera Rice', 'jeera rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jeera rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Curd Rice', 'curd rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'curd rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Pulav', 'veg pulav', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Peas Pulav', 'peas pulav', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'peas pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Green Peas Mushroom Pulav', 'green peas mushroom pulav', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas mushroom pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Pulav', 'cheese pulav', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kaju Pulav', 'kaju pulav', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Pulav', 'paneer pulav', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kashmiri Pulav', 'kashmiri pulav', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kashmiri pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Hanuman Sp. Handi Pulav', 'hanuman sp. handi pulav', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hanuman sp. handi pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg. Biryani', 'veg. biryani', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dum Biryani', 'dum biryani', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dum biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Handi Biryani', 'handi biryani', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'handi biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Biryani', 'mushroom biryani', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Hyderbadi Biryani', 'hyderbadi biryani', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hyderbadi biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Biryani', 'paneer biryani', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Soyabean Biryani', 'soyabean biryani', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'soyabean biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Hanuman Sp. Handi Biryani', 'hanuman sp. handi biryani', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hanuman sp. handi biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Tawa Biryani', 'tawa biryani', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tawa biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "KHICHDI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Palak Khichdi', 'palak khichdi', 'KHICHDI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak khichdi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "KHICHDI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dal Khichdi', 'dal khichdi', 'KHICHDI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal khichdi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "KHICHDI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Dal Khichdi Tadka', 'dal khichdi tadka', 'KHICHDI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal khichdi tadka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Tandoori Roti', 'tandoori roti', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tandoori roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 24.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Butter Roti', 'butter roti', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paratha', 'paratha', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Butter Paratha', 'butter paratha', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Naan', 'naan', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 45.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Butter Naan', 'butter naan', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kulcha', 'kulcha', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kulcha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Butter Kulcha', 'butter kulcha', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter kulcha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Naan', 'cheese naan', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Kashmiri Naan', 'kashmiri naan', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kashmiri naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Garlic Naan', 'cheese garlic naan', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese garlic naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Garlic Naan', 'garlic naan', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'garlic naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Ginger Naan', 'ginger naan', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ginger naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Stuff Paratha', 'veg stuff paratha', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg stuff paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Aloo Paratha', 'aloo paratha', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Methi Paratha', 'methi paratha', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'methi paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Onion Paratha', 'onion paratha', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'onion paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Meethi Roti', 'meethi roti', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'meethi roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Pudina Roti', 'pudina roti', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pudina roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Messi Roti', 'messi roti', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'messi roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Stuff Kulcha', 'stuff kulcha', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'stuff kulcha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Bhatura (Single)', 'bhatura (single)', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bhatura (single)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Puri Plate', 'puri plate', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'puri plate'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Roti Ki Tokri (Assorted)', 'roti ki tokri (assorted)', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'roti ki tokri (assorted)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "INDIAN BREAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Chapati', 'chapati', 'INDIAN BREAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chapati'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 12.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Clear Soup', 'veg clear soup', 'CHINESE SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg clear soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cream of Veg Soup', 'cream of veg soup', 'CHINESE SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cream of veg soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Noodle Soup', 'veg noodle soup', 'CHINESE SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg noodle soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Manchow Soup', 'manchow soup', 'CHINESE SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'manchow soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'French Onion Soup', 'french onion soup', 'CHINESE SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'french onion soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Soup', 'mushroom soup', 'CHINESE SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cream of Mushroom Soup', 'cream of mushroom soup', 'CHINESE SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cream of mushroom soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Sweet Corn Soup', 'sweet corn soup', 'CHINESE SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet corn soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Hot N Sour Soup', 'hot n sour soup', 'CHINESE SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hot n sour soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Tom Yum Soup (Thai)', 'tom yum soup (thai)', 'CHINESE SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tom yum soup (thai)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Oriental Soup', 'oriental soup', 'CHINESE SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'oriental soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Lung Fung Soup', 'lung fung soup', 'CHINESE SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'lung fung soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Idli Chilly', 'idli chilly', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'idli chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Crispy', 'veg crispy', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg crispy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Manchurian', 'veg manchurian', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Crispy Chilly Potato', 'crispy chilly potato', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'crispy chilly potato'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Chilly', 'veg chilly', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg 65', 'veg 65', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg 65'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Schezwan Finger', 'veg schezwan finger', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg schezwan finger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Chinese Bhel', 'chinese bhel', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chinese bhel'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Gold Coin', 'veg gold coin', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg gold coin'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Chilly', 'paneer chilly', 'CHINESE STARTERS (DRY)', 'veg', 'split-paneer-chilly-gravy', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.55, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.55 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Gravy', 'paneer gravy', 'CHINESE STARTERS (DRY)', 'veg', 'split-paneer-chilly-gravy', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer gravy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.55, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.55 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer 65', 'paneer 65', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer 65'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Satey', 'paneer satey', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer satey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Crispy', 'paneer crispy', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer crispy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Hunan', 'paneer hunan', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer hunan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Teriyaki', 'paneer teriyaki', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer teriyaki'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Panner Schezwan Finger', 'panner schezwan finger', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'panner schezwan finger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Salt n Pepper', 'paneer salt n pepper', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer salt n pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Spring Roll', 'veg spring roll', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg spring roll'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Panner Spring Roll', 'panner spring roll', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'panner spring roll'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Mushroom Spring Roll', 'paneer mushroom spring roll', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer mushroom spring roll'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Panner in Garlic Sauce', 'panner in garlic sauce', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'panner in garlic sauce'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Panner Burnt Garlic', 'panner burnt garlic', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'panner burnt garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Panner Manchurian', 'panner manchurian', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'panner manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Onion Roll (8 Pcs)', 'cheese onion roll (8 pcs)', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese onion roll (8 pcs)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Chilly Roll (8 Pcs)', 'cheese chilly roll (8 pcs)', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese chilly roll (8 pcs)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Chilly', 'mushroom chilly', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Manchurian', 'mushroom manchurian', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Salt n Pepper', 'mushroom salt n pepper', 'CHINESE STARTERS (DRY)', 'veg', 'split-mushroom-bobycorn-salt-n-pepper', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom salt n pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Bobycorn Salt n Pepper', 'bobycorn salt n pepper', 'CHINESE STARTERS (DRY)', 'veg', 'split-mushroom-bobycorn-salt-n-pepper', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bobycorn salt n pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Babycorn Manchurian', 'babycorn manchurian', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'babycorn manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Babycorn Chilly', 'babycorn chilly', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'babycorn chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer in Barbeque Sauce', 'paneer in barbeque sauce', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer in barbeque sauce'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Pepper Panner', 'pepper panner', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pepper panner'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Babycorn Mushroom Salt n Pepper', 'babycorn mushroom salt n pepper', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'babycorn mushroom salt n pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Stuffed Barbeque Mushroom', 'stuffed barbeque mushroom', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'stuffed barbeque mushroom'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Soyabean Manchurian', 'soyabean manchurian', 'CHINESE STARTERS (DRY)', 'veg', 'split-soyabean-manchurian-chilly', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'soyabean manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Soyabean Chilly', 'soyabean chilly', 'CHINESE STARTERS (DRY)', 'veg', 'split-soyabean-manchurian-chilly', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'soyabean chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "CHINESE STARTERS (DRY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Sesame Toast', 'sesame toast', 'CHINESE STARTERS (DRY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sesame toast'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mix Veg in Green Sauce', 'mix veg in green sauce', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix veg in green sauce'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Schezwan', 'veg schezwan', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Hongkong', 'veg hongkong', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg hongkong'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Schezwan Ball', 'veg schezwan ball', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg schezwan ball'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Schezwan (Gravy)', 'paneer schezwan (gravy)', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer schezwan (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Manchurian', 'mushroom manchurian', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Chilly', 'mushroom chilly', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Babycorn Mushroom in Green Sauce', 'babycorn mushroom in green sauce', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'babycorn mushroom in green sauce'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Soyabean Manchurian (Gravy)', 'soyabean manchurian (gravy)', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'soyabean manchurian (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Manchurian (Gravy)', 'veg manchurian (gravy)', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg manchurian (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Sweet n Sour', 'veg sweet n sour', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg sweet n sour'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer in Garlic Sauce', 'paneer in garlic sauce', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer in garlic sauce'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Chilly (Gravy)', 'paneer chilly (gravy)', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilly (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Babycorn Manchurian (Gravy)', 'babycorn manchurian (gravy)', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'split-babycorn-manchurian-chilly-gravy', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'babycorn manchurian (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Babycorn Chilly (Gravy)', 'babycorn chilly (gravy)', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'split-babycorn-manchurian-chilly-gravy', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'babycorn chilly (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Gobi Manchurian (Gravy)', 'gobi manchurian (gravy)', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'gobi manchurian (gravy)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "CHINESE MAIN COURSE (GRAVY)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Thai Curry (Red & Green)', 'thai curry (red & green)', 'CHINESE MAIN COURSE (GRAVY)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'thai curry (red & green)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Hakka Noodles', 'veg hakka noodles', 'NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg hakka noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Schezwan Noodles', 'veg schezwan noodles', 'NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg schezwan noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Singapore Noodles', 'veg singapore noodles', 'NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg singapore noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Hongkong Noodles', 'veg hongkong noodles', 'NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg hongkong noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 225.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Thai Basil Noodles', 'veg thai basil noodles', 'NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg thai basil noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Chowmein', 'veg chowmein', 'NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg chowmein'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'American Chopsuey', 'american chopsuey', 'NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'american chopsuey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Garlic Pepper Noodles', 'garlic pepper noodles', 'NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'garlic pepper noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Burnt Garlic Noodles', 'burnt garlic noodles', 'NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'burnt garlic noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Noodles', 'paneer noodles', 'NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Triple Schezwan Noodles', 'triple schezwan noodles', 'NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'triple schezwan noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Lemon Rice', 'lemon rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'lemon rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Fried Rice', 'fried rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Jeera Fried Rice', 'jeera fried rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jeera fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mix Fried Rice', 'mix fried rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Schezwan Fied Rice', 'schezwan fied rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'schezwan fied rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Fied Rice', 'paneer fied rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer fied rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Singapore Fried Rice', 'singapore fried rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'singapore fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Hongkong Fried Rice', 'hongkong fried rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hongkong fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Mushroom Fried Rice', 'mushroom fried rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Ginger Garlic Fried Rice', 'ginger garlic fried rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ginger garlic fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cantonese Fried Rice', 'cantonese fried rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cantonese fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Triple Schezwan Fried Rice', 'triple schezwan fried rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'triple schezwan fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Burnt Garlic Fried Rice', 'burnt garlic fried rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'burnt garlic fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Stewed Rice', 'veg stewed rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg stewed rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Manchurian Rice Combination', 'manchurian rice combination', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'manchurian rice combination'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Pot Rice', 'pot rice', 'RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pot rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Sandwich', 'veg sandwich', 'SANDWICHES', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg sandwich'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES ('Regular', TRUE), ('Grill', FALSE)) AS x(variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review'
  FROM new_variants nv JOIN (VALUES ('Regular', 80.00), ('Grill', 140.00)) AS x(variant_name, price_amount)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.72, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.72 FROM new_prices, ctx;

-- Source: docx, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Veg Cheese Sandwich', 'veg cheese sandwich', 'SANDWICHES', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg cheese sandwich'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES ('Regular', TRUE), ('Grill', FALSE)) AS x(variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review'
  FROM new_variants nv JOIN (VALUES ('Regular', 100.00), ('Grill', 190.00)) AS x(variant_name, price_amount)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.72, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.72 FROM new_prices, ctx;

-- Source: docx, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Tomato Omlet Sandwich', 'tomato omlet sandwich', 'SANDWICHES', 'egg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'tomato omlet sandwich' AND pt.code = 'egg'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.60, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Club Sandwich', 'club sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'club sandwich'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES ('Toasted', TRUE), ('Grill', FALSE)) AS x(variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified'
  FROM new_variants nv JOIN (VALUES ('Toasted', 170.00), ('Grill', 220.00)) AS x(variant_name, price_amount)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.88, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.88 FROM new_prices, ctx;

-- Source: docx, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Sandwich', 'paneer sandwich', 'SANDWICHES', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer sandwich'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES ('Regular', TRUE), ('Grill', FALSE)) AS x(variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review'
  FROM new_variants nv JOIN (VALUES ('Regular', 170.00), ('Grill', 220.00)) AS x(variant_name, price_amount)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.72, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.72 FROM new_prices, ctx;

-- Source: docx, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Paneer Tikka Grill', 'paneer tikka grill', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka grill'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Bread Butter', 'bread butter', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bread butter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Bread Jam', 'bread jam', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bread jam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Chilly Cheese Grill Sandwich', 'chilly cheese grill sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chilly cheese grill sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Plain Cheese Sandwich', 'plain cheese sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'plain cheese sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Chilly Toast', 'cheese chilly toast', 'SANDWICHES', 'veg', 'split-cheese-chilly-toast-cheese-garlic-toast', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese chilly toast'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT nextval('khaustan_menu_item_id_seq'), ctx.restaurant_id, item_cd.canonical_dish_id, 'Cheese Garlic Toast', 'cheese garlic toast', 'SANDWICHES', 'veg', 'split-cheese-chilly-toast-cheese-garlic-toast', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese garlic toast'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT nextval('khaustan_variant_id_seq'), menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT nextval('khaustan_price_id_seq'), new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- =============================================================================
-- ADDED IN THIS PASS (v4) -- re-examined against Hanuman_Veg_Treat_Menu_transcribed.docx
-- per explicit request: menu_board, delivery partners, and a check on schedule data.
-- =============================================================================

-- -----------------------------------------------------------------------
-- menu_board + menu_category + menu_board_category
-- Previously deliberately skipped (see the old UNMAPPED note below, now
-- superseded) in favor of raw_category_text alone. One board (this menu
-- has no bar/breakfast/other separately-branded section), one category
-- per distinct raw_category_text already used by the 404 existing
-- menu_item rows -- created here, then backfilled onto those rows by
-- UPDATE rather than touching any of the original 404 statements.
-- -----------------------------------------------------------------------
WITH new_board AS (
  INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
  SELECT nextval('khaustan_menu_board_id_seq'), ctx.restaurant_id, 'Hanuman Veg Treat Menu', 'a_la_carte'
  FROM khaustan_onboarding_ctx ctx
  RETURNING menu_board_id, restaurant_id
)
SELECT menu_board_id, restaurant_id INTO TEMP hvt_board FROM new_board;

WITH cats(seq, raw_text, display_name) AS (
  VALUES
    (1, 'SNACKS', 'Snacks'),
    (2, 'FASTING (UPVAS)', 'Fasting (Upvas)'),
    (3, 'DOSAS', 'Dosas'),
    (4, 'UTTAPPAM', 'Uttappam'),
    (5, 'SPECIAL DOSAS', 'Special Dosas'),
    (6, 'PAV BHAJI (AFTER 12.00 PM)', 'Pav Bhaji (After 12.00 Pm)'),
    (7, 'PIZZA', 'Pizza'),
    (8, 'BURGER / FRANKIES', 'Burger / Frankies'),
    (9, 'PASTA', 'Pasta'),
    (10, 'SIZZLERS', 'Sizzlers'),
    (11, 'LUNCH (11.00 AM TO 3.00 PM)', 'Lunch (11.00 Am To 3.00 Pm)'),
    (12, 'SOUP (INDIAN)', 'Soup (Indian)'),
    (13, 'INDIAN STARTERS (KADAI)', 'Indian Starters (Kadai)'),
    (14, 'STARTERS (TANDOOR)', 'Starters (Tandoor)'),
    (15, 'INDIAN MAIN COURSE', 'Indian Main Course'),
    (16, 'KADAI AUR HANDI KA KAMAL', 'Kadai Aur Handi Ka Kamal'),
    (17, 'MALWANI MAIN COURSE', 'Malwani Main Course'),
    (18, 'KAJU SPECIAL', 'Kaju Special'),
    (19, 'VEG (SWEET)', 'Veg (Sweet)'),
    (20, 'DAL', 'Dal'),
    (21, 'RICE', 'Rice'),
    (22, 'KHICHDI', 'Khichdi'),
    (23, 'INDIAN BREAD', 'Indian Bread'),
    (24, 'CHINESE SOUP', 'Chinese Soup'),
    (25, 'CHINESE STARTERS (DRY)', 'Chinese Starters (Dry)'),
    (26, 'CHINESE MAIN COURSE (GRAVY)', 'Chinese Main Course (Gravy)'),
    (27, 'NOODLES', 'Noodles'),
    (28, 'SANDWICHES', 'Sandwiches')
)
INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence)
SELECT nextval('khaustan_menu_category_id_seq'), b.restaurant_id, c.display_name, c.seq
FROM cats c CROSS JOIN hvt_board b
RETURNING menu_category_id, name;

-- Map raw_category_text -> the new menu_category_id, so the UPDATE below
-- doesn't depend on insertion order (name is unique enough here since
-- display_name is derived 1:1 from raw_text, but join on the actual text
-- next, not the title-cased name, to avoid any case-sensitivity surprise).
CREATE TEMP TABLE hvt_cat_map AS
SELECT mc.menu_category_id, c.raw_text
FROM menu_category mc
JOIN hvt_board b ON b.restaurant_id = mc.restaurant_id
JOIN (VALUES
    ('Snacks', 'SNACKS'),
    ('Fasting (Upvas)', 'FASTING (UPVAS)'),
    ('Dosas', 'DOSAS'),
    ('Uttappam', 'UTTAPPAM'),
    ('Special Dosas', 'SPECIAL DOSAS'),
    ('Pav Bhaji (After 12.00 Pm)', 'PAV BHAJI (AFTER 12.00 PM)'),
    ('Pizza', 'PIZZA'),
    ('Burger / Frankies', 'BURGER / FRANKIES'),
    ('Pasta', 'PASTA'),
    ('Sizzlers', 'SIZZLERS'),
    ('Lunch (11.00 Am To 3.00 Pm)', 'LUNCH (11.00 AM TO 3.00 PM)'),
    ('Soup (Indian)', 'SOUP (INDIAN)'),
    ('Indian Starters (Kadai)', 'INDIAN STARTERS (KADAI)'),
    ('Starters (Tandoor)', 'STARTERS (TANDOOR)'),
    ('Indian Main Course', 'INDIAN MAIN COURSE'),
    ('Kadai Aur Handi Ka Kamal', 'KADAI AUR HANDI KA KAMAL'),
    ('Malwani Main Course', 'MALWANI MAIN COURSE'),
    ('Kaju Special', 'KAJU SPECIAL'),
    ('Veg (Sweet)', 'VEG (SWEET)'),
    ('Dal', 'DAL'),
    ('Rice', 'RICE'),
    ('Khichdi', 'KHICHDI'),
    ('Indian Bread', 'INDIAN BREAD'),
    ('Chinese Soup', 'CHINESE SOUP'),
    ('Chinese Starters (Dry)', 'CHINESE STARTERS (DRY)'),
    ('Chinese Main Course (Gravy)', 'CHINESE MAIN COURSE (GRAVY)'),
    ('Noodles', 'NOODLES'),
    ('Sandwiches', 'SANDWICHES')
) AS c(display_name, raw_text) ON c.display_name = mc.name
WHERE mc.restaurant_id = (SELECT restaurant_id FROM hvt_board);

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
SELECT b.restaurant_id, b.menu_board_id, m.menu_category_id, row_number() OVER ()
FROM hvt_cat_map m CROSS JOIN hvt_board b;

-- Backfill menu_category_id onto the 404 existing menu_item rows by their
-- already-stored raw_category_text, then clear raw_category_text -- the
-- schema's own convention: NULL once menu_category_id is curated.
UPDATE menu_item mi
SET menu_category_id = m.menu_category_id,
    raw_category_text = NULL
FROM hvt_cat_map m
WHERE mi.raw_category_text = m.raw_text
  AND mi.restaurant_id = (SELECT restaurant_id FROM hvt_board);

-- menu_board_item: one row per existing menu_item, now that each has a
-- menu_category_id to carry along.
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
SELECT nextval('khaustan_menu_board_item_id_seq'), b.restaurant_id, b.menu_board_id, mi.menu_item_id, mi.menu_category_id
FROM menu_item mi CROSS JOIN hvt_board b
WHERE mi.restaurant_id = b.restaurant_id;

-- -----------------------------------------------------------------------
-- Zomato + Swiggy delivery partners.
-- Re-examined: the docx names both by name ("Facebook | Instagram |
-- SWIGGY | zomato") right under "FREE HOME DELIVERY" and four phone
-- numbers -- a restaurant doesn't point customers at a "rate us" link on
-- a platform it has no order-taking presence on. Reading this as
-- confirmation (not just the self-delivery-only reading the previous
-- version took) and linking both, same identify-only pattern as 'self':
-- if the lookup row doesn't exist, no link is created, nothing invented.
-- -----------------------------------------------------------------------
-- delivery_charge_type_code is NOT NULL with only 'fixed'/'percentage' as
-- valid values (no "unknown" option) -- 'fixed' is used here as a required
-- structural placeholder only. The actual delivery fee on Zomato/Swiggy is
-- each platform's own dynamic charge, not something the docx states or this
-- script should assert, so base_delivery_charge is left NULL rather than a
-- guessed number (unlike the 'self' link above, where NULL/0.00 reflects
-- the docx's own stated "FREE").
INSERT INTO restaurant_delivery_provider (
  restaurant_delivery_provider_id, restaurant_id, delivery_provider_id,
  delivery_charge_type_code, effective_from
)
SELECT nextval('khaustan_onboarding_id_seq'), ctx.restaurant_id, dp.delivery_provider_id,
       'fixed', (clock_timestamp() AT TIME ZONE 'UTC')
FROM khaustan_onboarding_ctx ctx
JOIN delivery_provider dp ON dp.provider_code IN ('ZOMATO', 'SWIGGY');

COMMIT;

-- =============================================================================
-- REVIEW NOTES: every menu_item / menu_item_price row inserted above with
-- verification_status_code = 'needs_review' (confidence < 0.8), one line
-- each, in the order they were inserted.
-- =============================================================================
-- NEEDS_REVIEW [0.60] "Tomato Omlet" (UTTAPPAM): Printed as "Omlet" in a restaurant whose own name is "Veg. Treat" and whose full menu is otherwise 100% vegetarian -- may be a besan/gram-flour veg imitation dish rather than a true egg dish. Classified 'egg' (the literal reading) rather than assumed veg, since that is the safer default for anyone filtering on this field; confirm with the restaurant.
-- NEEDS_REVIEW [0.60] "Cheese Tomato Omlet" (UTTAPPAM): Printed as "Omlet" in a restaurant whose own name is "Veg. Treat" and whose full menu is otherwise 100% vegetarian -- may be a besan/gram-flour veg imitation dish rather than a true egg dish. Classified 'egg' (the literal reading) rather than assumed veg, since that is the safer default for anyone filtering on this field; confirm with the restaurant.
-- NEEDS_REVIEW [0.70] "Extra Plain Pav" (PAV BHAJI (AFTER 12.00 PM)): Reconstructed from a compressed line ('Extra Plain Pav / Butter Pav', 07/16); assumed 'Extra' applies to both halves. Verify against the printed menu.
-- NEEDS_REVIEW [0.70] "Extra Butter Pav" (PAV BHAJI (AFTER 12.00 PM)): Reconstructed from a compressed line ('Extra Plain Pav / Butter Pav', 07/16); assumed 'Extra' applies to both halves. Verify against the printed menu.
-- NEEDS_REVIEW [0.70] "Paneer Tikka (8 Pcs.)" (STARTERS (TANDOOR)): 'Yellow / Red' has no legend on the page; read as two marinade-color variants of one dish (both priced the same) rather than two separate dishes.
-- NEEDS_REVIEW [0.70] "Achari Aloo Tikka" (STARTERS (TANDOOR)): Reconstructed from a compressed line ('Achari Aloo / Soyabean Tikka', 180/200); assumed 'Achari' and 'Tikka' both apply to each half. Verify against the printed menu.
-- NEEDS_REVIEW [0.70] "Achari Soyabean Tikka" (STARTERS (TANDOOR)): Reconstructed from a compressed line ('Achari Aloo / Soyabean Tikka', 180/200); assumed 'Achari' and 'Tikka' both apply to each half. Verify against the printed menu.
-- NEEDS_REVIEW [0.50] "Green Peas Gobi" (INDIAN MAIN COURSE): Raw line 'Green Peas Gobi / Fry Masala | 195' is unclear (possible OCR/print garble); read as two dishes sharing one price. Needs confirmation against the printed menu.
-- NEEDS_REVIEW [0.50] "Green Peas Fry Masala" (INDIAN MAIN COURSE): Raw line 'Green Peas Gobi / Fry Masala | 195' is unclear (possible OCR/print garble); read as two dishes sharing one price. Needs confirmation against the printed menu.
-- NEEDS_REVIEW [0.75] "Steam Rice" (RICE): 'F / H' has no legend on this line; read as Full/Half by standard menu convention, not explicitly confirmed in the document.
-- NEEDS_REVIEW [0.55] "Paneer Chilly" (CHINESE STARTERS (DRY)): Raw line 'Paneer Chilly / Gravy | 240/250' is ambiguous (dry-style variant vs. two separate dishes); read as two dishes. Note a separate, differently-priced 'Paneer Chilly (Gravy)' (Rs 230) also appears later under Chinese Main Course (Gravy) -- reconcile with the restaurant.
-- NEEDS_REVIEW [0.55] "Paneer Gravy" (CHINESE STARTERS (DRY)): Raw line 'Paneer Chilly / Gravy | 240/250' is ambiguous (dry-style variant vs. two separate dishes); read as two dishes. Note a separate, differently-priced 'Paneer Chilly (Gravy)' (Rs 230) also appears later under Chinese Main Course (Gravy) -- reconcile with the restaurant.
-- NEEDS_REVIEW [0.72] "Veg Sandwich" (SANDWICHES): No explicit parentheses on this line; 'Grill' read as a preparation-style variant by analogy to 'Club Sandwich (Toasted / Grill)' elsewhere in this section.
-- NEEDS_REVIEW [0.72] "Veg Cheese Sandwich" (SANDWICHES): Same reasoning as 'Veg Sandwich / Veg Grill' -- 'Grill' read as a variant of this dish by analogy, not explicit parentheses on this line.
-- NEEDS_REVIEW [0.60] "Tomato Omlet Sandwich" (SANDWICHES): Printed as "Omlet" in a restaurant whose own name is "Veg. Treat" and whose full menu is otherwise 100% vegetarian -- may be a besan/gram-flour veg imitation dish rather than a true egg dish. Classified 'egg' (the literal reading) rather than assumed veg, since that is the safer default for anyone filtering on this field; confirm with the restaurant.
-- NEEDS_REVIEW [0.72] "Paneer Sandwich" (SANDWICHES): Same reasoning as the other Sandwich/Grill lines in this section.

-- =============================================================================
-- UNMAPPED: restaurant-level facts from the docx with no clean schema home,
-- or deliberately left for a human decision even with the full DDL in hand.
-- =============================================================================
-- UNMAPPED: "Government taxes as applicable" (footer note) confirms GST is
--   charged on top of the printed prices. menu_item_price.tax_regime_code
--   is explicitly commented "open/externally-driven" in the DDL itself,
--   and tax_inclusion_code / tax_rate have no stated convention either, so
--   none of the three are populated here.
-- UNMAPPED: "Please Like & Rate us on Facebook | Instagram | SWIGGY |
--   zomato" only appears in a ratings/review-page context in the docx, not
--   explicit order-taking language, so no delivery_provider /
--   restaurant_delivery_provider rows were created for Zomato or Swiggy --
--   only 'self' (see the self-delivery block above). They may well also be
--   live order channels; the docx text alone doesn't confirm it.
-- UNMAPPED: three blanket surcharge notes have no unambiguous per-item
--   qualifying list, so none were attached to menu_item_charge even though
--   its exact columns are now known: charge_id, menu_item_id,
--   service_mode_id, charge_type_code, calculation_type_code ('fixed' or
--   'percentage'), amount, percentage, tax_regime_code, effective_from,
--   effective_to, is_active.
--     - "(All Ghee / Butter Items will be charge Rs. 20/-)" (DOSAS section)
--     - "(Any Extra Topping Rs. 40/-, Extra Cheese Rs. 40/-)" (PIZZA section)
--     - "(Bread Toast will be charges extra 20/-)" (SANDWICHES section)
--   Once the qualifying items are confirmed, each is one row per item:
--   INSERT INTO menu_item_charge (charge_id, menu_item_id, charge_type_code,
--   calculation_type_code, amount, effective_from) VALUES (nextval(...),
--   <menu_item_id>, 'ghee_butter_surcharge', 'fixed', 20.00, now()).
-- UNMAPPED: restaurant.veg_nonveg_status left NULL -- resolving it means
--   first resolving the Omlet classification below (pure_veg only holds if
--   those three items are confirmed egg-free).
-- UNMAPPED: restaurant_phone.is_personal_number left FALSE (default) on all
--   four numbers -- the docx gives no way to tell a personal mobile line
--   from a dedicated business line, and this column exists specifically
--   for that DPDP-relevant distinction.
-- RESOLVED IN v4: menu_board / menu_category, previously deferred here, are
--   now created and backfilled onto all 404 menu_item rows -- see the block
--   before COMMIT. Category names are the raw text titlecased verbatim
--   (e.g. "Pav Bhaji (After 12.00 Pm)"); a curator may still want to rename
--   or re-tree these, this just stops deferring the base structure.
-- UNMAPPED: many item names carry likely transcription typos relative to
--   their correctly-spelled counterparts elsewhere in the SAME docx (e.g.
--   "Panner" vs "Paneer", "Masal" vs "Masala", "Fied" vs "Fried",
--   "Bobycorn" vs "Babycorn", "Jalfrazi"/"Jalraize" vs "Jalfrezi",
--   "Hyderbadi" vs "Hyderabadi"). Each spelling was kept verbatim and
--   resolves to its OWN canonical_dish rather than being silently merged
--   with its correctly-spelled counterpart (conservative-matching: exact
--   normalized match only). A human curator may want to alias or merge
--   these; this script does not guess.
