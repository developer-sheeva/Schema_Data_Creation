-- =====================================================================================
-- khaustan_load_menu_json.sql        Khaustan menu-JSON -> PostgreSQL loader   (reference v1.0)
-- Target : database KhaustanRestaurantMenu. Validated on PostgreSQL 16.15; expected to work on 14+ (not tested).
-- Needs   : pg_trgm for the fuzzy tier (optional; the script skips that tier if the extension is absent).
--
-- RUN (psql)  : psql -d KhaustanRestaurantMenu -v json_file=/path/to/menu.json -f khaustan_load_menu_json.sql
--               (Windows: change `cat` to `type` in the \set line of STEP 1)
-- RUN (GUI)   : use STEP 1 variant B: delete the three psql lines of variant A, paste the JSON between the
--               $ldr_json$ tags. Everything after STEP 1 is plain SQL (no psql meta-commands), so it runs in
--               pgAdmin, DBeaver, the Neon SQL editor or psycopg. Read the LAST result set: it is the report.
--
-- CONNECTION  : use a DIRECT connection (not a transaction-mode pooler such as PgBouncer / Neon '-pooler' host):
--               the report is read from a session temp table after COMMIT. In a GUI, if an earlier run failed in
--               the same session, run ROLLBACK first.
-- GUARANTEES  : one transaction (all or nothing) | INSERT-only into the 14 tables listed in STEP 9
--               NEVER inserts, updates or deletes lookup tables, canonical_dish, canonical_dish_name, brand
--               DDL limited to ldr_seq_* sequences and TEMP objects, all closed/dropped before COMMIT
-- =====================================================================================
\set ON_ERROR_STOP on

BEGIN;
DROP TABLE IF EXISTS pg_temp.ldr_report;   -- report of a previous run in this same session

-- ---------------------------------------------------------------------
-- STEP 0  close (drop) loader sequences left over from earlier runs
-- ---------------------------------------------------------------------
DO $ldr$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, c.relname
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind = 'S'
       AND c.relname LIKE 'ldr\_seq\_%'
       AND n.nspname = current_schema()
       AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype IN ('a','i'))
  LOOP
    EXECUTE format('DROP SEQUENCE %I.%I', r.nspname, r.relname);
    RAISE NOTICE 'closed leftover sequence %.%', r.nspname, r.relname;
  END LOOP;
END
$ldr$;

-- ---------------------------------------------------------------------
-- STEP 1  input document. Use EXACTLY ONE of the two variants.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE ldr_input (doc jsonb NOT NULL) ON COMMIT DROP;

-- variant A (psql): the file is read client-side, so no server file access is needed
\set menu_json `cat :'json_file'`
INSERT INTO ldr_input VALUES (:'menu_json'::jsonb);
SELECT set_config('ldr.source_file', :'json_file', true);

-- variant B (GUI / any client): delete the three variant-A lines above, then uncomment and paste here
-- INSERT INTO ldr_input VALUES ($ldr_json$
-- { ...paste the whole JSON document here... }
-- $ldr_json$::jsonb);
-- SELECT set_config('ldr.source_file', 'pasted-json', true);

-- ---------------------------------------------------------------------
-- STEP 2  parameters, helper functions, abbreviation dictionary
-- ---------------------------------------------------------------------
CREATE TEMP TABLE ldr_param (k text PRIMARY KEY, v text NOT NULL) ON COMMIT DROP;
INSERT INTO ldr_param VALUES
  ('fuzzy_enabled',        'on'),     -- tier 4 (pg_trgm) on/off
  ('fuzzy_min_sim',        '0.70'),   -- minimum trigram similarity for an automatic link
  ('fuzzy_min_margin',     '0.05'),   -- best candidate must beat the runner-up by this much
  ('token_sim_min',        '0.45'),   -- the single differing word must still look like a spelling variant
  ('market_tokens',        'market price|m.p.|m.p|mp|market rate|as per market price'),
  ('default_variant_name', 'Regular'),
  ('board_name',           'Main Menu'),
  ('board_type_code',      'a_la_carte'),
  -- snapshot of Canonical_Dish.csv: the canonical_dish table must still equal it
  ('canon_rows',           '4377'),
  ('canon_min_id',         '10001'),
  ('canon_max_id',         '60465'),
  ('canon_ids_md5',        'dfd259ae460e22bf5b83ea02a9fa2356'),
  ('canon_names_md5',      'fe69f825c43d80bceabf8df4a0846a1e');

CREATE OR REPLACE FUNCTION pg_temp.ldr_norm(t text) RETURNS text LANGUAGE sql IMMUTABLE AS
$$ SELECT btrim(regexp_replace(lower(t), '[^[:alnum:]]+', ' ', 'g')) $$;

CREATE OR REPLACE FUNCTION pg_temp.ldr_clean_name(t text) RETURNS text LANGUAGE sql IMMUTABLE AS
$$ SELECT btrim(regexp_replace(regexp_replace(t, '\s*\*\s*new\y', '', 'gi'), '\s+', ' ', 'g')) $$;

CREATE OR REPLACE FUNCTION pg_temp.ldr_strip_parens(t text) RETURNS text LANGUAGE sql IMMUTABLE AS
$$ SELECT btrim(regexp_replace(t, '\([^)]*\)', ' ', 'g')) $$;

CREATE TEMP TABLE ldr_abbrev (abbr text PRIMARY KEY, full_word text NOT NULL) ON COMMIT DROP;
INSERT INTO ldr_abbrev VALUES
  ('chi','chicken'),('chic','chicken'),('mut','mutton'),('spl','special'),('sp','special'),
  ('schn','schezwan'),('schezn','schezwan'),('vegetable','veg'),('vegetables','veg'),
  ('pcs','pc'),('piece','pc'),('pieces','pc');

CREATE OR REPLACE FUNCTION pg_temp.ldr_expand(t text) RETURNS text LANGUAGE sql STABLE AS
$$ SELECT coalesce(string_agg(coalesce(a.full_word, w.tok), ' ' ORDER BY w.ord), '')
     FROM unnest(string_to_array(t, ' ')) WITH ORDINALITY AS w(tok, ord)
     LEFT JOIN ldr_abbrev a ON a.abbr = w.tok $$;

-- strip a trailing "(Full / Half)"-style parenthetical when ALL its parts are this item's own price labels
CREATE OR REPLACE FUNCTION pg_temp.ldr_strip_portion(nm text, labels text[]) RETURNS text LANGUAGE plpgsql IMMUTABLE AS $f$
DECLARE paren text;
BEGIN
  paren := substring(nm from '\(([^()]*)\)\s*$');
  IF paren IS NULL OR labels IS NULL OR cardinality(labels) = 0 THEN RETURN nm; END IF;
  IF NOT EXISTS (
       SELECT 1 FROM unnest(string_to_array(paren, '/')) AS part
        WHERE pg_temp.ldr_norm(part) NOT IN (SELECT pg_temp.ldr_norm(l) FROM unnest(labels) l)
     ) THEN
    RETURN btrim(regexp_replace(nm, '\s*\([^()]*\)\s*$', ''));
  END IF;
  RETURN nm;
END $f$;

-- ---------------------------------------------------------------------
-- STEP 3  parse the restaurant block
-- ---------------------------------------------------------------------
CREATE TEMP TABLE ldr_ctx ON COMMIT DROP AS
SELECT
  nullif(btrim(r->>'name'),'')                                        AS name,
  nullif(btrim(r->>'address'),'')                                     AS address,
  coalesce(nullif(btrim(r->>'pincode'),''), nullif(btrim(r->>'postal_code'),''),
           substring(r->>'address' from '(?:^|[^0-9])([1-9][0-9]{5})[^0-9]*$')) AS pin,
  nullif(btrim(r->>'establishment_id'),'')                            AS est_id_in,
  nullif(btrim(r->>'restaurant_id'),'')                               AS rest_id_in,
  nullif(btrim(r->>'phone'),'')                                       AS phone,
  nullif(btrim(r->>'email'),'')                                       AS email,
  nullif(btrim(r->>'website'),'')                                     AS website,
  nullif(btrim(r->>'minimum_delivery_price'),'')                      AS min_delivery,
  nullif(btrim(r->>'timing'),'')                                      AS timing,
  nullif(btrim(r->>'latitude'),'')                                    AS lat_in,
  nullif(btrim(r->>'longitude'),'')                                   AS lon_in,
  nullif(btrim(r->>'city'),'')                                        AS city_in,
  nullif(btrim(r->>'state'),'')                                       AS state_in,
  nullif(btrim(r->>'locality'),'')                                    AS locality_in,
  NULL::bigint AS establishment_id, NULL::bigint AS restaurant_id, NULL::bigint AS id_base,
  NULL::text   AS id_rule, NULL::text AS city, NULL::text AS state, NULL::text AS address_line1,
  NULL::boolean AS has_trgm,
  (clock_timestamp() AT TIME ZONE 'UTC') AS load_ts
FROM (SELECT doc->'restaurant' AS r FROM ldr_input) s;

-- ---------------------------------------------------------------------
-- STEP 4  flatten pages -> sections -> (nested) columns -> items
-- ---------------------------------------------------------------------
CREATE TEMP TABLE ldr_walk ON COMMIT DROP AS
WITH RECURSIVE w(page_no, sec_no, path, top_cat, sub_cat, node, depth, labels) AS (
  SELECT p.n::int, s.n::int, ARRAY[p.n::int, s.n::int], nullif(btrim(s.v->>'category'),''), NULL::text, s.v, 1, 0
    FROM ldr_input i
   CROSS JOIN LATERAL jsonb_array_elements(i.doc->'pages') WITH ORDINALITY AS p(v, n)
   CROSS JOIN LATERAL jsonb_array_elements(coalesce(p.v->'sections','[]'::jsonb)) WITH ORDINALITY AS s(v, n)
  UNION ALL
  SELECT w.page_no, w.sec_no, w.path || c.n::int, w.top_cat,
         coalesce(nullif(btrim(c.v->>'category'),''), nullif(btrim(c.v->>'subcategory'),''), w.sub_cat),
         c.v, w.depth + 1,
         w.labels + CASE WHEN nullif(btrim(c.v->>'category'),'') IS NOT NULL OR nullif(btrim(c.v->>'subcategory'),'') IS NOT NULL THEN 1 ELSE 0 END
    FROM w
   CROSS JOIN LATERAL jsonb_array_elements(coalesce(w.node->'columns','[]'::jsonb)) WITH ORDINALITY AS c(v, n)
)
SELECT * FROM w;

CREATE TEMP TABLE ldr_item_raw ON COMMIT DROP AS
SELECT row_number() OVER (ORDER BY w.page_no, w.path, it.n)::int AS ord,
       w.page_no, w.top_cat, w.sub_cat,
       nullif(btrim(it.v->>'name'),'')  AS raw_name,
       it.v->>'price'                   AS price_raw,
       it.v->'prices'                   AS prices
  FROM ldr_walk w
 CROSS JOIN LATERAL jsonb_array_elements(coalesce(w.node->'items','[]'::jsonb)) WITH ORDINALITY AS it(v, n);

-- cleaned display name, keys, combined-line flag (items with no name are skipped and reported)
CREATE TEMP TABLE ldr_item_stg ON COMMIT DROP AS
SELECT r.*,
       n.name_clean,
       pg_temp.ldr_norm(n.name_clean)                                  AS full_plain,
       pg_temp.ldr_expand(pg_temp.ldr_norm(n.name_clean))              AS full_exp,
       pg_temp.ldr_expand(pg_temp.ldr_norm(pg_temp.ldr_strip_parens(n.name_clean))) AS core_exp,
       (pg_temp.ldr_strip_parens(n.name_clean) ~ '(\s/\s)|(\w{3,}/\w{3,})')        AS combined
  FROM (SELECT * FROM ldr_item_raw WHERE raw_name IS NOT NULL) r
 CROSS JOIN LATERAL (
   SELECT pg_temp.ldr_strip_portion(
            pg_temp.ldr_clean_name(r.raw_name),
            ARRAY(SELECT btrim(p->>'label') FROM jsonb_array_elements(coalesce(r.prices,'[]'::jsonb)) p)
          ) AS name_clean
 ) n;

-- OCR free-text lines (never loaded as menu content; only scanned for review warnings)
CREATE TEMP TABLE ldr_other_text ON COMMIT DROP AS
SELECT pg.n::int AS page_no, t.n::int AS line_no, btrim(t.v #>> '{}') AS txt
  FROM ldr_input i
 CROSS JOIN LATERAL jsonb_array_elements(i.doc->'pages') WITH ORDINALITY AS pg(v, n)
 CROSS JOIN LATERAL jsonb_array_elements(coalesce(pg.v->'other_text','[]'::jsonb)) WITH ORDINALITY AS t(v, n);

-- ---------------------------------------------------------------------
-- STEP 5  validate, resolve city/state, allocate establishment_id / restaurant_id
-- ---------------------------------------------------------------------
DO $ldr$
DECLARE
  c        ldr_ctx%ROWTYPE;
  pinbase  bigint;  mx bigint;  est bigint;  rid bigint;  n bigint;
  rule     text;
  segs     text[];  last_seg text;  state_p text;  city_p text;  line1 text;
  t        record;
  n_cat int; n_item int; n_var int;
  snap     record;
BEGIN
  SELECT * INTO c FROM ldr_ctx;

  IF to_regclass('establishment') IS NULL OR to_regclass('canonical_dish') IS NULL THEN
    RAISE EXCEPTION 'Connect to the KhaustanRestaurantMenu database before running this script'; END IF;
  IF jsonb_typeof((SELECT doc->'restaurant' FROM ldr_input)) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'JSON: "restaurant" object is missing'; END IF;
  IF jsonb_typeof((SELECT doc->'pages' FROM ldr_input)) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'JSON: "pages" array is missing'; END IF;
  IF c.name IS NULL THEN RAISE EXCEPTION 'JSON: restaurant.name is required'; END IF;
  IF (SELECT count(*) FROM ldr_item_stg) = 0 THEN RAISE EXCEPTION 'JSON: no menu items found under pages[].sections[]'; END IF;
  IF EXISTS (SELECT 1 FROM ldr_walk WHERE labels > 1) THEN
    RAISE EXCEPTION 'JSON: category nesting is deeper than two levels (page %, section %). Flatten the JSON or extend the loader.',
      (SELECT page_no FROM ldr_walk WHERE labels > 1 ORDER BY page_no, path LIMIT 1),
      (SELECT sec_no  FROM ldr_walk WHERE labels > 1 ORDER BY page_no, path LIMIT 1); END IF;

  -- 5a  PIN
  IF c.pin IS NULL OR c.pin !~ '^[1-8][0-9]{5}$' THEN
    RAISE EXCEPTION 'PIN code missing or invalid (need 6 digits, first digit 1-8). Add restaurant.pincode to the JSON. Found: %', coalesce(c.pin,'<none>'); END IF;
  pinbase := c.pin::bigint * 1000;

  -- 5b  IDs supplied in the JSON must be well-formed
  IF c.est_id_in IS NOT NULL AND (c.est_id_in !~ '^[1-9][0-9]{8}$' OR left(c.est_id_in,6) <> c.pin) THEN
    RAISE EXCEPTION 'establishment_id % must be exactly 9 digits and start with the PIN %', c.est_id_in, c.pin; END IF;
  IF c.rest_id_in IS NOT NULL AND c.rest_id_in !~ '^[1-9][0-9]{0,14}$' THEN
    RAISE EXCEPTION 'restaurant_id % must be a positive integer of at most 15 digits', c.rest_id_in; END IF;

  -- 5c  establishment_id / restaurant_id decision table
  IF c.est_id_in IS NOT NULL THEN
    est := c.est_id_in::bigint;  rule := 'establishment_id from JSON';
  ELSIF c.rest_id_in IS NOT NULL THEN
    IF c.rest_id_in !~ '^[1-9][0-9]{8}$' OR left(c.rest_id_in,6) <> c.pin THEN
      RAISE EXCEPTION 'restaurant_id % cannot also be the establishment_id (needs 9 digits starting with PIN %). Supply establishment_id in the JSON.', c.rest_id_in, c.pin; END IF;
    est := c.rest_id_in::bigint; rule := 'establishment_id = restaurant_id from JSON';
  ELSE
    PERFORM pg_advisory_xact_lock(hashtextextended('khaustan_loader_pin_' || c.pin, 0));
    SELECT max(establishment_id) INTO mx FROM establishment WHERE establishment_id BETWEEN pinbase AND pinbase + 999;
    IF mx IS NULL THEN est := pinbase + 1;
    ELSIF mx >= pinbase + 999 THEN RAISE EXCEPTION 'PIN % is full: establishment_id % already used (max 999 per PIN)', c.pin, mx;
    ELSE est := mx + 1; END IF;
    rule := CASE WHEN mx IS NULL THEN 'allocated: first establishment on PIN' ELSE 'allocated: last on PIN (' || mx || ') + 1' END;
  END IF;
  rid := coalesce(c.rest_id_in::bigint, est);
  IF c.rest_id_in IS NULL THEN rule := rule || '; restaurant_id = establishment_id'; END IF;

  IF EXISTS (SELECT 1 FROM establishment WHERE establishment_id = est) THEN
    RAISE EXCEPTION 'establishment_id % already exists', est; END IF;
  IF EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = rid) THEN
    RAISE EXCEPTION 'restaurant_id % already exists', rid; END IF;
  IF EXISTS (SELECT 1 FROM establishment WHERE postal_code = c.pin AND normalized_name = pg_temp.ldr_norm(c.name)) THEN
    RAISE EXCEPTION 'Possible duplicate: an establishment named "%" already exists on PIN % (id %). Aborting; nothing loaded.',
      c.name, c.pin, (SELECT min(establishment_id) FROM establishment WHERE postal_code = c.pin AND normalized_name = pg_temp.ldr_norm(c.name)); END IF;

  -- 5d  child-ID block <restaurant_id>001 .. <restaurant_id>999 must be empty in every sequenced table
  FOR t IN SELECT * FROM (VALUES
      ('menu_category','menu_category_id'), ('menu_item','menu_item_id'), ('menu_item_variant','variant_id'),
      ('menu_item_price','price_id'), ('menu_item_availability','availability_id'), ('menu_board_item','menu_board_item_id'),
      ('menu_board','menu_board_id'), ('source_record','source_id'), ('menu_extraction_batch','extraction_batch_id'),
      ('restaurant_phone','restaurant_phone_id')) AS v(tbl, col)
  LOOP
    EXECUTE format('SELECT count(*) FROM %I WHERE %I BETWEEN $1 AND $2', t.tbl, t.col) INTO n USING rid*1000, rid*1000+999;
    IF n > 0 THEN RAISE EXCEPTION 'ID block %..% is not empty in %.% (% rows)', rid*1000+1, rid*1000+999, t.tbl, t.col, n; END IF;
  END LOOP;

  -- 5e  capacity: at most 999 rows per sequenced table for one restaurant
  SELECT count(*) INTO n_item FROM ldr_item_stg;
  SELECT count(*) INTO n_cat FROM (
      SELECT DISTINCT pg_temp.ldr_norm(top_cat), pg_temp.ldr_norm(sub_cat) FROM ldr_item_stg WHERE top_cat IS NOT NULL) x;
  SELECT coalesce(sum(CASE WHEN prices IS NOT NULL AND jsonb_typeof(prices)='array' AND jsonb_array_length(prices) > 0
                           THEN jsonb_array_length(prices) ELSE 1 END), 0) INTO n_var FROM ldr_item_stg;
  IF n_cat + (SELECT count(DISTINCT pg_temp.ldr_norm(top_cat)) FROM ldr_item_stg WHERE top_cat IS NOT NULL AND sub_cat IS NOT NULL) > 999
     OR n_item > 999 OR n_var > 999 THEN
    RAISE EXCEPTION 'Capacity: <restaurant_id>001..999 allows 999 rows per table. This file needs items=%, variants/prices=%.', n_item, n_var; END IF;

  -- 5f  canonical_dish snapshot must equal the attached CSV (count, id range, id hash)
  SELECT count(*) AS cnt, min(canonical_dish_id) AS lo, max(canonical_dish_id) AS hi,
         md5(string_agg(canonical_dish_id::text, E'\n' ORDER BY canonical_dish_id)) AS ids_md5,
         md5(string_agg(canonical_dish_id::text || ':' || canonical_name, E'\n' ORDER BY canonical_dish_id)) AS names_md5
    INTO snap FROM canonical_dish;
  IF snap.cnt <> (SELECT v::bigint FROM ldr_param WHERE k = 'canon_rows')
     OR snap.lo <> (SELECT v::bigint FROM ldr_param WHERE k = 'canon_min_id')
     OR snap.hi <> (SELECT v::bigint FROM ldr_param WHERE k = 'canon_max_id')
     OR snap.ids_md5 <> (SELECT v FROM ldr_param WHERE k = 'canon_ids_md5') THEN
    RAISE EXCEPTION 'canonical_dish does not match the Canonical_Dish.csv snapshot (rows %, min %, max %, ids_md5 %). Re-export the CSV or update the canon_* parameters.', snap.cnt, snap.lo, snap.hi, snap.ids_md5; END IF;
  IF snap.names_md5 <> (SELECT v FROM ldr_param WHERE k = 'canon_names_md5') THEN
    RAISE WARNING 'canonical_dish names differ from the CSV (ids identical). Matching uses the database names.'; END IF;

  -- 5g  city / state / address_line1 (no silent schema defaults)
  segs := regexp_split_to_array(c.address, '\s*,\s*');
  last_seg := segs[array_length(segs,1)];
  state_p := btrim(regexp_replace(last_seg, '[0-9]{6}\s*\W*$', ''));
  IF lower(state_p) NOT IN ('andhra pradesh','arunachal pradesh','assam','bihar','chhattisgarh','goa','gujarat','haryana',
      'himachal pradesh','jharkhand','karnataka','kerala','madhya pradesh','maharashtra','manipur','meghalaya','mizoram','nagaland',
      'odisha','punjab','rajasthan','sikkim','tamil nadu','telangana','tripura','uttar pradesh','uttarakhand','west bengal',
      'andaman and nicobar islands','chandigarh','dadra and nagar haveli and daman and diu','delhi','jammu and kashmir','ladakh',
      'lakshadweep','puducherry') THEN state_p := NULL; END IF;
  IF state_p IS NOT NULL AND array_length(segs,1) >= 3 THEN
    city_p := segs[array_length(segs,1)-1];
    line1  := array_to_string(segs[1:array_length(segs,1)-2], ', ');
  END IF;
  UPDATE ldr_ctx SET establishment_id = est, restaurant_id = rid, id_base = rid*1000, id_rule = rule,
         state = coalesce(c.state_in, state_p), city = coalesce(c.city_in, city_p),
         address_line1 = coalesce(line1, c.address),
         has_trgm = EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm');
  IF (SELECT city FROM ldr_ctx) IS NULL OR (SELECT state FROM ldr_ctx) IS NULL THEN
    RAISE EXCEPTION 'Cannot derive city/state from the address "%". Add restaurant.city and restaurant.state to the JSON.', c.address; END IF;
END
$ldr$;

-- ---------------------------------------------------------------------
-- STEP 6  create the loader sequences  (START = <restaurant_id>001, MAXVALUE = <restaurant_id>999, NO CYCLE)
-- ---------------------------------------------------------------------
DO $ldr$
DECLARE b bigint; t text;
BEGIN
  SELECT id_base INTO b FROM ldr_ctx;
  FOREACH t IN ARRAY ARRAY['menu_category','menu_item','menu_item_variant','menu_item_price','menu_item_availability',
                           'menu_board_item','menu_board','source_record','menu_extraction_batch','restaurant_phone']
  LOOP
    EXECUTE format('CREATE SEQUENCE %I START WITH %s MINVALUE %s MAXVALUE %s NO CYCLE', 'ldr_seq_' || t, b+1, b+1, b+999);
  END LOOP;
END
$ldr$;

-- ---------------------------------------------------------------------
-- STEP 7  assign IDs in document order
-- ---------------------------------------------------------------------
CREATE TEMP TABLE ldr_cat ON COMMIT DROP AS
SELECT nextval('ldr_seq_menu_category') AS menu_category_id, x.*
  FROM (
    SELECT 1 AS lvl, k AS cat_key, NULL::text AS parent_key, nm AS name, first_ord
      FROM (SELECT pg_temp.ldr_norm(top_cat) AS k, (array_agg(top_cat ORDER BY ord))[1] AS nm, min(ord) AS first_ord
              FROM ldr_item_stg WHERE top_cat IS NOT NULL GROUP BY 1) tops
    UNION ALL
    SELECT 2, pk || '>' || k, pk, nm, first_ord
      FROM (SELECT pg_temp.ldr_norm(top_cat) AS pk, pg_temp.ldr_norm(sub_cat) AS k, (array_agg(sub_cat ORDER BY ord))[1] AS nm, min(ord) AS first_ord
              FROM ldr_item_stg WHERE top_cat IS NOT NULL AND sub_cat IS NOT NULL GROUP BY 1,2) subs
    ORDER BY first_ord, lvl
  ) x;

CREATE TEMP TABLE ldr_item ON COMMIT DROP AS
SELECT nextval('ldr_seq_menu_item') AS menu_item_id, s.*
  FROM (SELECT i.*, CASE WHEN i.top_cat IS NULL THEN NULL
                         WHEN i.sub_cat IS NOT NULL THEN pg_temp.ldr_norm(i.top_cat) || '>' || pg_temp.ldr_norm(i.sub_cat)
                         ELSE pg_temp.ldr_norm(i.top_cat) END AS cat_key
          FROM ldr_item_stg i ORDER BY i.ord) s;

CREATE TEMP TABLE ldr_var ON COMMIT DROP AS
SELECT nextval('ldr_seq_menu_item_variant') AS variant_id, v.*
  FROM (
    SELECT i.menu_item_id, i.ord AS item_ord, 1 AS var_no, (SELECT x.v FROM ldr_param x WHERE x.k = 'default_variant_name') AS variant_name, i.price_raw AS ptoken
      FROM ldr_item i
     WHERE i.prices IS NULL OR jsonb_typeof(i.prices) <> 'array' OR jsonb_array_length(i.prices) = 0
    UNION ALL
    SELECT i.menu_item_id, i.ord, p.n::int, coalesce(nullif(btrim(p.v->>'label'),''), (SELECT x.v FROM ldr_param x WHERE x.k = 'default_variant_name')), p.v->>'price'
      FROM ldr_item i CROSS JOIN LATERAL jsonb_array_elements(i.prices) WITH ORDINALITY AS p(v, n)
     WHERE jsonb_typeof(i.prices) = 'array'
    ORDER BY 2, 3
  ) v;

CREATE TEMP TABLE ldr_price ON COMMIT DROP AS
SELECT nextval('ldr_seq_menu_item_price') AS price_id, p.*
  FROM (
    SELECT v.variant_id,
           CASE WHEN btrim(v.ptoken) ~* '^(₹|rs\.?|inr)?\s*[0-9]+(\.[0-9]{1,2})?\s*(/-|/=)?$'
                THEN substring(btrim(v.ptoken) from '([0-9]+(?:\.[0-9]{1,2})?)')::numeric(12,2) END AS amount,
           (lower(btrim(v.ptoken)) = ANY (string_to_array((SELECT x.v FROM ldr_param x WHERE x.k = 'market_tokens'), '|'))) AS is_market
      FROM ldr_var v ORDER BY v.variant_id
  ) p
 WHERE p.amount IS NOT NULL OR p.is_market;

-- ---------------------------------------------------------------------
-- STEP 8  canonical_dish matching (reads canonical_dish; NEVER inserts into it)
-- ---------------------------------------------------------------------
CREATE TEMP TABLE ldr_canon ON COMMIT DROP AS
SELECT canonical_dish_id AS id, canonical_name,
       pg_temp.ldr_norm(pg_temp.ldr_clean_name(canonical_name))                                              AS full_plain,
       pg_temp.ldr_expand(pg_temp.ldr_norm(pg_temp.ldr_clean_name(canonical_name)))                          AS full_exp,
       pg_temp.ldr_expand(pg_temp.ldr_norm(pg_temp.ldr_strip_parens(pg_temp.ldr_clean_name(canonical_name)))) AS core_exp,
       (canonical_name LIKE '%*%')                                                                           AS has_star
  FROM canonical_dish;

CREATE TEMP TABLE ldr_match (ord int PRIMARY KEY, canonical_dish_id bigint NOT NULL, tier text NOT NULL, score numeric, note text) ON COMMIT DROP;

INSERT INTO ldr_match
SELECT i.ord, (array_agg(c.id ORDER BY c.has_star, c.id))[1], 'T1_exact', 1.0,
       CASE WHEN count(*) > 1 THEN 'tie_broken: ' || count(*) || ' candidates' END
  FROM ldr_item i JOIN ldr_canon c ON c.full_plain = i.full_plain
 WHERE NOT i.combined GROUP BY i.ord;

INSERT INTO ldr_match
SELECT i.ord, (array_agg(c.id ORDER BY c.has_star, c.id))[1], 'T2_expanded', 1.0,
       CASE WHEN count(*) > 1 THEN 'tie_broken: ' || count(*) || ' candidates' END
  FROM ldr_item i JOIN ldr_canon c ON c.full_exp = i.full_exp
 WHERE NOT i.combined AND i.ord NOT IN (SELECT ord FROM ldr_match) GROUP BY i.ord;

INSERT INTO ldr_match
SELECT i.ord, (array_agg(c.id ORDER BY (c.full_exp = i.core_exp) DESC, c.has_star, c.id))[1], 'T3_core', 0.95,
       CASE WHEN count(*) > 1 THEN 'tie_broken: ' || count(*) || ' candidates' END
  FROM ldr_item i JOIN ldr_canon c ON c.full_exp = i.core_exp OR c.core_exp = i.full_exp OR c.core_exp = i.core_exp
 WHERE NOT i.combined AND i.ord NOT IN (SELECT ord FROM ldr_match) GROUP BY i.ord;

-- helper for the fuzzy tier: critical tokens must agree and at most one differing token (a spelling variant) per side
CREATE OR REPLACE FUNCTION pg_temp.ldr_token_guard(a text, b text, tok_min numeric) RETURNS boolean LANGUAGE plpgsql STABLE AS $f$
DECLARE ta text[] := string_to_array(a, ' ');  tb text[] := string_to_array(b, ' ');
        crit text[] := ARRAY['veg','non','chicken','mutton','paneer','egg','prawn','prawns','fish','seafood','beef','pork','lamb','crab','mushroom','cheese'];
        ao text[]; bo text[];
BEGIN
  IF (SELECT coalesce(array_agg(DISTINCT t ORDER BY t), '{}') FROM unnest(ta) t WHERE t = ANY(crit))
     IS DISTINCT FROM
     (SELECT coalesce(array_agg(DISTINCT t ORDER BY t), '{}') FROM unnest(tb) t WHERE t = ANY(crit)) THEN RETURN false; END IF;
  ao := ARRAY(SELECT unnest(ta) EXCEPT SELECT unnest(tb));
  bo := ARRAY(SELECT unnest(tb) EXCEPT SELECT unnest(ta));
  IF cardinality(ao) = 0 AND cardinality(bo) = 0 THEN RETURN true; END IF;
  IF cardinality(ao) = 1 AND cardinality(bo) = 1 THEN RETURN similarity(ao[1], bo[1]) >= tok_min; END IF;
  RETURN false;
END $f$;

CREATE TEMP TABLE ldr_canon_key ON COMMIT DROP AS
SELECT DISTINCT ON (core_exp) core_exp, id AS rep_id, canonical_name AS rep_name
  FROM ldr_canon ORDER BY core_exp, has_star, id;

DO $ldr$
BEGIN
  IF (SELECT has_trgm FROM ldr_ctx) AND (SELECT v FROM ldr_param WHERE k = 'fuzzy_enabled') = 'on' THEN
    EXECUTE 'SET LOCAL pg_trgm.similarity_threshold = 0.3';
    EXECUTE 'CREATE INDEX ldr_canon_key_trgm ON ldr_canon_key USING gin (core_exp gin_trgm_ops)';
    EXECUTE $q$
      CREATE TEMP TABLE ldr_cand ON COMMIT DROP AS
      SELECT r.*, row_number() OVER (PARTITION BY r.ord ORDER BY r.sim DESC, r.rep_id) AS rn
        FROM (SELECT u.ord, u.core_exp AS icore, k.core_exp AS ccore, k.rep_id, k.rep_name,
                     similarity(u.core_exp, k.core_exp) AS sim
                FROM ldr_item u JOIN ldr_canon_key k ON k.core_exp % u.core_exp
               WHERE NOT u.combined AND u.ord NOT IN (SELECT ord FROM ldr_match)) r $q$;
    EXECUTE $q$
      INSERT INTO ldr_match
      SELECT b.ord, b.rep_id, 'T4_fuzzy', round(b.sim::numeric, 3),
             'fuzzy sim=' || round(b.sim::numeric,3) || ' margin=' || round((b.sim - coalesce(s.sim,0))::numeric,3) || ' -> ' || b.rep_name
        FROM ldr_cand b LEFT JOIN ldr_cand s ON s.ord = b.ord AND s.rn = 2
       WHERE b.rn = 1
         AND b.sim >= (SELECT v::numeric FROM ldr_param WHERE k = 'fuzzy_min_sim')
         AND b.sim - coalesce(s.sim,0) >= (SELECT v::numeric FROM ldr_param WHERE k = 'fuzzy_min_margin')
         AND pg_temp.ldr_token_guard(b.icore, b.ccore, (SELECT v::numeric FROM ldr_param WHERE k = 'token_sim_min')) $q$;
  ELSE
    RAISE NOTICE 'fuzzy tier skipped (pg_trgm missing or fuzzy_enabled=off); exact / abbreviation / qualifier tiers still ran';
    EXECUTE 'CREATE TEMP TABLE ldr_cand (ord int, icore text, ccore text, rep_id bigint, rep_name text, sim real, rn bigint) ON COMMIT DROP';
  END IF;
END
$ldr$;

-- ---------------------------------------------------------------------
-- STEP 9  inserts (FK-safe order). Allowed targets only; no UPDATE/DELETE on existing rows.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE ldr_ids ON COMMIT DROP AS
SELECT nextval('ldr_seq_source_record') AS source_id,
       nextval('ldr_seq_menu_extraction_batch') AS batch_id,
       nextval('ldr_seq_menu_board') AS board_id;

INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, locality, city, state,
                           postal_code, email_id, website_url, latitude, longitude)
SELECT establishment_id, name, pg_temp.ldr_norm(name), left(address_line1, 300), locality_in, city, state, pin, email, website,
       CASE WHEN lat_in ~ '^-?[0-9]+(\.[0-9]+)?$' THEN CASE WHEN lat_in::numeric BETWEEN -90  AND 90  THEN lat_in::numeric(17,14) END END,
       CASE WHEN lon_in ~ '^-?[0-9]+(\.[0-9]+)?$' THEN CASE WHEN lon_in::numeric BETWEEN -180 AND 180 THEN lon_in::numeric(17,14) END END
  FROM ldr_ctx;

INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name)
SELECT restaurant_id, establishment_id, name, pg_temp.ldr_norm(name) FROM ldr_ctx;

INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
SELECT nextval('ldr_seq_restaurant_phone'), (SELECT restaurant_id FROM ldr_ctx), p.num, (p.n = 1)
  FROM (SELECT x.num, row_number() OVER (ORDER BY min(x.ord)) AS n
          FROM (SELECT regexp_replace(t.part, '[^0-9+]', '', 'g') AS num, t.ord
                  FROM ldr_ctx, regexp_split_to_table(ldr_ctx.phone, '\s*[/,;]\s*') WITH ORDINALITY AS t(part, ord)) x
         WHERE length(x.num) BETWEEN 8 AND 15 GROUP BY x.num) p
 ORDER BY p.n;

INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available, self_delivery_min_order_amount, currency_code)
SELECT restaurant_id, TRUE, TRUE, substring(min_delivery from '([0-9]+(?:\.[0-9]{1,2})?)')::numeric(12,2), 'INR'
  FROM ldr_ctx WHERE min_delivery ~ '[0-9]';

INSERT INTO source_record (source_id, source_type_code, external_reference, source_uri)
SELECT source_id, 'ai_menu_extraction', 'menu_json_loader md5:' || (SELECT md5(doc::text) FROM ldr_input),
       left(nullif(current_setting('ldr.source_file', true), ''), 1000) FROM ldr_ids;

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
SELECT i.batch_id, c.restaurant_id, i.source_id, c.load_ts, c.load_ts, 'completed' FROM ldr_ids i, ldr_ctx c;

INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
SELECT i.board_id, c.restaurant_id, (SELECT v FROM ldr_param WHERE k = 'board_name'), (SELECT v FROM ldr_param WHERE k = 'board_type_code') FROM ldr_ids i, ldr_ctx c;

INSERT INTO menu_category (menu_category_id, restaurant_id, parent_category_id, name, display_sequence)
SELECT c.menu_category_id, (SELECT restaurant_id FROM ldr_ctx), p.menu_category_id, left(c.name, 200),
       (row_number() OVER (PARTITION BY c.parent_key ORDER BY c.first_ord, c.menu_category_id))::int
  FROM ldr_cat c LEFT JOIN ldr_cat p ON p.cat_key = c.parent_key
 ORDER BY c.menu_category_id;

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
SELECT (SELECT restaurant_id FROM ldr_ctx), (SELECT board_id FROM ldr_ids), c.menu_category_id,
       (row_number() OVER (ORDER BY c.first_ord, c.lvl))::int
  FROM ldr_cat c;

INSERT INTO menu_item (menu_item_id, restaurant_id, menu_category_id, canonical_dish_id, name, normalized_name)
SELECT i.menu_item_id, (SELECT restaurant_id FROM ldr_ctx), c.menu_category_id, m.canonical_dish_id,
       left(i.name_clean, 250), pg_temp.ldr_norm(i.name_clean)
  FROM ldr_item i
  LEFT JOIN ldr_cat c ON c.cat_key = i.cat_key
  LEFT JOIN ldr_match m ON m.ord = i.ord
 ORDER BY i.menu_item_id;

INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id)
SELECT i.menu_item_id, d.source_id, d.batch_id FROM ldr_item i, ldr_ids d;

INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
SELECT nextval('ldr_seq_menu_board_item'), (SELECT restaurant_id FROM ldr_ctx), (SELECT board_id FROM ldr_ids),
       s.menu_item_id, s.menu_category_id, s.ord
  FROM (SELECT i.menu_item_id, c.menu_category_id, i.ord
          FROM ldr_item i LEFT JOIN ldr_cat c ON c.cat_key = i.cat_key ORDER BY i.ord) s;

INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, display_sequence, is_default)
SELECT variant_id, menu_item_id, left(variant_name, 150), 'fixed', var_no, (var_no = 1) FROM ldr_var ORDER BY variant_id;

INSERT INTO menu_item_price (price_id, variant_id, price_amount, currency_code, is_market_price, effective_from,
                             verification_status_code, source_id)
SELECT p.price_id, p.variant_id, p.amount, 'INR', coalesce(p.is_market, FALSE) AND p.amount IS NULL, c.load_ts, 'unverified', d.source_id
  FROM ldr_price p, ldr_ctx c, ldr_ids d ORDER BY p.price_id;

-- ---------------------------------------------------------------------
-- STEP 10  report (one table, read after COMMIT)
-- ---------------------------------------------------------------------
CREATE TEMP TABLE ldr_report (sec_order int, section text, ref text, label text, detail text);

INSERT INTO ldr_report
SELECT 1, 'IDS', 'json_md5', md5(doc::text), left(coalesce(nullif(current_setting('ldr.source_file', true), ''), '(no file name)'), 200) FROM ldr_input
UNION ALL SELECT 1, 'IDS', 'establishment_id', establishment_id::text, id_rule FROM ldr_ctx
UNION ALL SELECT 1, 'IDS', 'restaurant_id', restaurant_id::text, 'child IDs: ' || (id_base+1) || ' .. ' || (id_base+999) FROM ldr_ctx
UNION ALL SELECT 1, 'IDS', 'PIN', pin, 'city=' || city || ', state=' || state FROM ldr_ctx;

INSERT INTO ldr_report
SELECT 2, 'ROWS_INSERTED', t, NULL, n::text FROM (
  SELECT 'establishment' AS t, count(*) AS n FROM establishment WHERE establishment_id = (SELECT establishment_id FROM ldr_ctx)
  UNION ALL SELECT 'restaurant', count(*) FROM restaurant WHERE restaurant_id = (SELECT restaurant_id FROM ldr_ctx)
  UNION ALL SELECT 'restaurant_phone', count(*) FROM restaurant_phone WHERE restaurant_id = (SELECT restaurant_id FROM ldr_ctx)
  UNION ALL SELECT 'restaurant_delivery', count(*) FROM restaurant_delivery WHERE restaurant_id = (SELECT restaurant_id FROM ldr_ctx)
  UNION ALL SELECT 'source_record', count(*) FROM source_record WHERE source_id = (SELECT source_id FROM ldr_ids)
  UNION ALL SELECT 'menu_extraction_batch', count(*) FROM menu_extraction_batch WHERE restaurant_id = (SELECT restaurant_id FROM ldr_ctx)
  UNION ALL SELECT 'menu_board', count(*) FROM menu_board WHERE restaurant_id = (SELECT restaurant_id FROM ldr_ctx)
  UNION ALL SELECT 'menu_category', count(*) FROM menu_category WHERE restaurant_id = (SELECT restaurant_id FROM ldr_ctx)
  UNION ALL SELECT 'menu_board_category', count(*) FROM menu_board_category WHERE restaurant_id = (SELECT restaurant_id FROM ldr_ctx)
  UNION ALL SELECT 'menu_item', count(*) FROM menu_item WHERE restaurant_id = (SELECT restaurant_id FROM ldr_ctx)
  UNION ALL SELECT 'menu_item_source', count(*) FROM menu_item_source WHERE menu_item_id IN (SELECT menu_item_id FROM ldr_item)
  UNION ALL SELECT 'menu_board_item', count(*) FROM menu_board_item WHERE restaurant_id = (SELECT restaurant_id FROM ldr_ctx)
  UNION ALL SELECT 'menu_item_variant', count(*) FROM menu_item_variant WHERE menu_item_id IN (SELECT menu_item_id FROM ldr_item)
  UNION ALL SELECT 'menu_item_price', count(*) FROM menu_item_price WHERE variant_id IN (SELECT variant_id FROM ldr_var)
  UNION ALL SELECT 'menu_item_availability (no source data)', 0
) q;

INSERT INTO ldr_report
SELECT 3, 'CANONICAL_SUMMARY', coalesce(m.tier, 'UNMATCHED'), NULL, count(*)::text
  FROM ldr_item i LEFT JOIN ldr_match m ON m.ord = i.ord GROUP BY coalesce(m.tier, 'UNMATCHED');
INSERT INTO ldr_report
SELECT 3, 'CANONICAL_SUMMARY', 'of which combined "A / B" lines', NULL, count(*)::text FROM ldr_item WHERE combined;

-- every menu item that did NOT get a canonical_dish_id (the list you asked for)
INSERT INTO ldr_report
SELECT 4, 'UNMATCHED_CANONICAL', i.menu_item_id::text, i.name_clean,
       CASE WHEN i.combined THEN 'combined line (A / B): not auto-linked, split manually'
            WHEN s.rep_id IS NULL THEN 'no candidate'
            ELSE 'no safe match; best suggestion ' || s.rep_id || ' "' || s.rep_name || '" sim=' || round(s.sim::numeric,3) END
  FROM ldr_item i
  LEFT JOIN ldr_match m ON m.ord = i.ord
  LEFT JOIN ldr_cand s ON s.ord = i.ord AND s.rn = 1
 WHERE m.ord IS NULL;

-- links that deserve a human look: fuzzy tier and tie-breaks (qualifier-core links are only counted in the summary)
INSERT INTO ldr_report
SELECT 5, 'REVIEW_LINKS', i.menu_item_id::text, i.name_clean,
       m.tier || ' -> ' || m.canonical_dish_id || ' "' || c.canonical_name || '"' || coalesce(' [' || m.note || ']', '')
  FROM ldr_item i JOIN ldr_match m ON m.ord = i.ord JOIN canonical_dish c ON c.canonical_dish_id = m.canonical_dish_id
 WHERE m.tier = 'T4_fuzzy' OR m.note LIKE 'tie_broken%';

INSERT INTO ldr_report
SELECT 6, 'NO_PRICE_ROW', i.menu_item_id::text, i.name_clean || ' [' || v.variant_name || ']',
       'price token "' || coalesce(v.ptoken,'') || '" is empty or not numeric: no menu_item_price row created'
  FROM ldr_var v JOIN ldr_item i ON i.menu_item_id = v.menu_item_id
 WHERE NOT EXISTS (SELECT 1 FROM ldr_price p WHERE p.variant_id = v.variant_id);

INSERT INTO ldr_report
SELECT 7, 'WARNING', 'categories', k.name, 'items found on non-adjacent pages (' || k.pages || '): same-named sections were merged'
  FROM (SELECT c.name, string_agg(DISTINCT i.page_no::text, ',' ORDER BY i.page_no::text) AS pages,
               max(i.page_no) - min(i.page_no) + 1 AS span, count(DISTINCT i.page_no) AS npages
          FROM ldr_item i JOIN ldr_cat c ON c.cat_key = i.cat_key GROUP BY c.name) k
 WHERE k.span <> k.npages;
INSERT INTO ldr_report
SELECT 7, 'WARNING', 'other_text', 'page ' || page_no, 'handwritten/OCR note, verify prices by hand: ' || txt
  FROM ldr_other_text WHERE txt ILIKE '%handwritten%';
INSERT INTO ldr_report
SELECT 7, 'WARNING', 'timing', timing, 'free-text opening hours NOT loaded (restaurant_hours needs structured days/times)' FROM ldr_ctx WHERE timing IS NOT NULL;
INSERT INTO ldr_report
SELECT 7, 'WARNING', 'restaurant_phone', count(*)::text, 'is_personal_number left at the schema default FALSE: confirm business vs personal lines (DPDP)'
  FROM restaurant_phone WHERE restaurant_id = (SELECT restaurant_id FROM ldr_ctx) HAVING count(*) > 0;
INSERT INTO ldr_report
SELECT 7, 'WARNING', 'menu_item_variant', count(*)::text, 'single-price items got the default variant name (parameter default_variant_name); pricing_basis fixed'
  FROM ldr_var WHERE variant_name = (SELECT v FROM ldr_param WHERE k = 'default_variant_name');
INSERT INTO ldr_report
SELECT 7, 'WARNING', 'restaurant_delivery', min_delivery, 'self-delivery flags set TRUE because a delivery minimum was printed: confirm'
  FROM ldr_ctx WHERE min_delivery ~ '[0-9]';
INSERT INTO ldr_report
SELECT 7, 'WARNING', 'multi-price labels', i.name_clean, 'variants from labels: ' || string_agg(v.variant_name, ' | ' ORDER BY v.var_no) || ' (check these are portions, not separate dishes)'
  FROM ldr_item i JOIN ldr_var v ON v.menu_item_id = i.menu_item_id
 WHERE jsonb_typeof(i.prices) = 'array' AND jsonb_array_length(i.prices) > 0
   AND EXISTS (SELECT 1 FROM ldr_var x WHERE x.menu_item_id = i.menu_item_id AND pg_temp.ldr_norm(x.variant_name) NOT IN ('full','half','big','small','large','medium','regular','mini'))
 GROUP BY i.menu_item_id, i.name_clean;

INSERT INTO ldr_report
SELECT 7, 'WARNING', 'pricing basis', i.name_clean, 'name carries a weight/quantity qualifier; pricing_basis_code left "fixed", quantity NULL: review'
  FROM ldr_item i WHERE i.name_clean ~* '(per\s*(kg|pailee|plate|piece)|\m[0-9]+\s*(kg|gm|g|ml|ltr|l|pc|pcs)\M)';
INSERT INTO ldr_report
SELECT 7, 'WARNING', 'tag candidate (NOT loaded)', o.txt, 'OCR text equals existing platform_tag ' || t.tag_code || ' (' || t.tag_scope || '): add restaurant_tag manually if intended'
  FROM ldr_other_text o JOIN platform_tag t ON pg_temp.ldr_norm(o.txt) IN (pg_temp.ldr_norm(t.name), pg_temp.ldr_norm(t.tag_code));
INSERT INTO ldr_report
SELECT 7, 'WARNING', 'items without category', count(*)::text, 'inserted with menu_category_id NULL' FROM ldr_item WHERE cat_key IS NULL HAVING count(*) > 0;
INSERT INTO ldr_report
SELECT 7, 'WARNING', 'nameless items skipped', count(*)::text, 'JSON items with an empty name were not loaded' FROM ldr_item_raw WHERE raw_name IS NULL HAVING count(*) > 0;
INSERT INTO ldr_report
SELECT 7, 'WARNING', 'duplicate item names', name_clean, count(*)::text || ' items share this normalized name' FROM ldr_item GROUP BY full_plain, name_clean HAVING count(*) > 1;

-- ---------------------------------------------------------------------
-- STEP 11  close (drop) every sequence this run created, then prove none are left
-- ---------------------------------------------------------------------
DO $ldr$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, c.relname
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind = 'S' AND c.relname LIKE 'ldr\_seq\_%' AND n.nspname = current_schema()
       AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype IN ('a','i'))
  LOOP
    EXECUTE format('DROP SEQUENCE %I.%I', r.nspname, r.relname);
  END LOOP;
END
$ldr$;
INSERT INTO ldr_report
SELECT 8, 'SEQUENCES', 'ldr_seq_* remaining', NULL, count(*)::text
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE c.relkind = 'S' AND c.relname LIKE 'ldr\_seq\_%' AND n.nspname = current_schema();

COMMIT;

\pset pager off
SELECT section, ref, label, detail FROM ldr_report ORDER BY sec_order, ref, label;
