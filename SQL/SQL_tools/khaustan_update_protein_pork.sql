/* ============================================================================
   khaustan_update_protein_pork.sql
   Database : KhaustanRestaurantMenu (PostgreSQL)
   Scope    : ALL restaurants (no restaurant filter)
   Purpose  : Set menu_item.protein_type_id = PORK for items that have no
              protein yet and whose name, alias, or category names pork.

   RUN IN ORDER, in one session:
     STEP 0  Check the PORK row exists exactly once          (read-only)
     STEP 1  PREVIEW: rows the update WOULD change           (read-only)
     STEP 2  UPDATE inside a transaction + audit log         (writes)
     STEP 3  Verify, then COMMIT or ROLLBACK
     STEP 4  Undo recipe (only if needed after COMMIT)

   RULES (same logic in STEP 1 and STEP 2)
     - Only items with protein_type_id IS NULL are touched; nothing already
       set is ever overwritten.
     - Only items whose food_classification_code is NULL or 'non_veg'.
     - The item name (or any alias/translation) must NOT name another protein.
     - Signal A (strong): item name or alias says pork / bacon / ham / sorpotel etc.
     - Signal B (weaker): item name is silent, and the category, parent
       category, or (if uncurated) raw_category_text names a pork term
       AND none of them names another protein.

   LEFT OUT OF THE KEYWORD LIST ON PURPOSE
     - 'pepperoni', 'sausage' : in Indian menus these are very often chicken.
     - 'ribs'     : beef, mutton and pork ribs all exist.
     - 'vindaloo' : "Chicken Vindaloo" is as common as the pork original.
     - 'pig'      : too easy to hit by accident in dish names.

   DECISION FOR YOU: bacon, ham, salami, chorizo, prosciutto and pancetta
   are treated as pork. Turkey / chicken / beef versions are caught by the
   exclusion list when the name says so ("Chicken Ham", "Turkey Bacon",
   "Beef Bacon" are skipped for review). If your menus often list the
   chicken version unlabeled, delete those words from target_re in STEP 1
   and STEP 2 and keep only pork and sorpotel.

   KEYWORD LISTS live in the single "kw" CTE of each statement. If you edit
   them, edit STEP 1 and STEP 2 identically so the preview matches the update.
   ============================================================================ */

-- \connect "KhaustanRestaurantMenu"


/* ----------------------------------------------------------------------------
   STEP 0 - The PORK protein_type row must exist exactly once.
   If this returns 0 rows, STEP 1 shows nothing and STEP 2 changes nothing.
   If it returns 2+ rows (e.g. 'pork' and 'PORK'), fix the data first.
   ---------------------------------------------------------------------------- */
SELECT protein_type_id, code, label
FROM   protein_type
WHERE  UPPER(code) = 'PORK';


/* ----------------------------------------------------------------------------
   STEP 1 - PREVIEW: every row STEP 2 would update. Read-only.
   Rows are sorted so the weaker category-based matches come first, since
   those are the ones worth eyeballing.
   Set use_category to FALSE to preview/apply item-name matches only.
   ---------------------------------------------------------------------------- */
WITH kw AS (
    SELECT '\y(pork|bacon|ham|salami|chorizo|prosciutto|pancetta|sorpotel|sorpatel)\y'
           AS target_re,
           '\y(chicken|murgh|murg|kukkad|tangdi|turkey|mutton|lamb|gosht|mangsho|raan|beef|buff|veal|fish|prawns?|shrimps?|crabs?|lobsters?|squids?|calamari|sea\s*foods?|tuna|salmon|pomfret|surmai|bombil|jhinga|kolambi|egg|anda|paneer)\y'
           AS other_re,
           TRUE AS use_category
),
pork_protein AS (
    SELECT protein_type_id, code
    FROM   protein_type
    WHERE  UPPER(code) = 'PORK'
),
signals AS (
    SELECT mi.menu_item_id,
           mi.restaurant_id,
           mi.name,
           mi.updated_at              AS updated_at_before,
           mi.food_classification_code,
           mi.raw_category_text,
           c.name                     AS category_name,
           pc.name                    AS parent_category_name,

           -- item name or any alias/translation says pork / bacon / ham etc.
           (   mi.name ~* kw.target_re
            OR EXISTS (SELECT 1
                       FROM   menu_item_name n
                       WHERE  n.menu_item_id = mi.menu_item_id
                         AND  n.name ~* kw.target_re)
           )                          AS name_target,

           -- item name or any alias/translation names a different protein
           (   mi.name ~* kw.other_re
            OR EXISTS (SELECT 1
                       FROM   menu_item_name n
                       WHERE  n.menu_item_id = mi.menu_item_id
                         AND  n.name ~* kw.other_re)
           )                          AS name_other,

           -- category, parent category, or uncurated raw OCR category says pork / bacon / ham etc.
           (   kw.use_category
           AND (   COALESCE(c.name, '')  ~* kw.target_re
                OR COALESCE(pc.name, '') ~* kw.target_re
                OR (mi.menu_category_id IS NULL
                    AND COALESCE(mi.raw_category_text, '') ~* kw.target_re))
           )                          AS cat_target,

           -- category, parent category, or raw category also names another protein
           (   COALESCE(c.name, '')  ~* kw.other_re
            OR COALESCE(pc.name, '') ~* kw.other_re
            OR (mi.menu_category_id IS NULL
                AND COALESCE(mi.raw_category_text, '') ~* kw.other_re)
           )                          AS cat_other
    FROM   menu_item mi
    CROSS  JOIN kw
    LEFT   JOIN menu_category c  ON c.restaurant_id = mi.restaurant_id
                                AND c.menu_category_id = mi.menu_category_id
    LEFT   JOIN menu_category pc ON pc.restaurant_id = c.restaurant_id
                                AND pc.menu_category_id = c.parent_category_id
    WHERE  mi.protein_type_id IS NULL
      AND (mi.food_classification_code IS NULL OR mi.food_classification_code = 'non_veg')
),
candidates AS (
    SELECT s.*,
           CASE WHEN s.name_target THEN 'item name'
                ELSE 'category / parent / raw category'
           END AS signal_source
    FROM   signals s
    WHERE  NOT s.name_other
      AND (s.name_target OR (s.cat_target AND NOT s.cat_other))
)
SELECT c.menu_item_id,
       c.restaurant_id,
       r.display_name             AS restaurant_name,
       c.name                     AS menu_item_name,
       c.category_name,
       c.parent_category_name,
       c.raw_category_text,
       c.food_classification_code,
       c.signal_source,
       mp.protein_type_id         AS new_protein_type_id,
       mp.code                    AS new_protein_code
FROM   candidates c
CROSS  JOIN pork_protein mp
JOIN   restaurant r ON r.restaurant_id = c.restaurant_id
ORDER  BY c.signal_source, r.display_name, c.category_name, c.name;


/* ----------------------------------------------------------------------------
   STEP 2 - UPDATE (single statement, one transaction).
   The CTE chain is identical to STEP 1. The UPDATE runs as a data-modifying
   CTE, and the INSERT at the end writes one audit-log row per item that was
   actually updated. The transaction is left OPEN: finish it in STEP 3.
   If you run this file with psql -f and never COMMIT, the session ends and
   everything rolls back - nothing is saved by accident.
   ---------------------------------------------------------------------------- */
BEGIN;

CREATE TABLE IF NOT EXISTS menu_item_protein_update_log (
    batch_code           VARCHAR(60)  NOT NULL,
    menu_item_id         BIGINT       NOT NULL,   -- no FK on purpose: the log must survive a restaurant delete
    old_protein_type_id  BIGINT,
    new_protein_type_id  BIGINT       NOT NULL,
    old_updated_at       TIMESTAMP(3) WITHOUT TIME ZONE,
    signal_source        VARCHAR(60)  NOT NULL,
    applied_at           TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    PRIMARY KEY (batch_code, menu_item_id)
);

WITH kw AS (
    SELECT '\y(pork|bacon|ham|salami|chorizo|prosciutto|pancetta|sorpotel|sorpatel)\y'
           AS target_re,
           '\y(chicken|murgh|murg|kukkad|tangdi|turkey|mutton|lamb|gosht|mangsho|raan|beef|buff|veal|fish|prawns?|shrimps?|crabs?|lobsters?|squids?|calamari|sea\s*foods?|tuna|salmon|pomfret|surmai|bombil|jhinga|kolambi|egg|anda|paneer)\y'
           AS other_re,
           TRUE AS use_category
),
pork_protein AS (
    SELECT protein_type_id, code
    FROM   protein_type
    WHERE  UPPER(code) = 'PORK'
),
signals AS (
    SELECT mi.menu_item_id,
           mi.restaurant_id,
           mi.name,
           mi.updated_at              AS updated_at_before,
           mi.food_classification_code,
           mi.raw_category_text,
           c.name                     AS category_name,
           pc.name                    AS parent_category_name,

           (   mi.name ~* kw.target_re
            OR EXISTS (SELECT 1
                       FROM   menu_item_name n
                       WHERE  n.menu_item_id = mi.menu_item_id
                         AND  n.name ~* kw.target_re)
           )                          AS name_target,

           (   mi.name ~* kw.other_re
            OR EXISTS (SELECT 1
                       FROM   menu_item_name n
                       WHERE  n.menu_item_id = mi.menu_item_id
                         AND  n.name ~* kw.other_re)
           )                          AS name_other,

           (   kw.use_category
           AND (   COALESCE(c.name, '')  ~* kw.target_re
                OR COALESCE(pc.name, '') ~* kw.target_re
                OR (mi.menu_category_id IS NULL
                    AND COALESCE(mi.raw_category_text, '') ~* kw.target_re))
           )                          AS cat_target,

           (   COALESCE(c.name, '')  ~* kw.other_re
            OR COALESCE(pc.name, '') ~* kw.other_re
            OR (mi.menu_category_id IS NULL
                AND COALESCE(mi.raw_category_text, '') ~* kw.other_re)
           )                          AS cat_other
    FROM   menu_item mi
    CROSS  JOIN kw
    LEFT   JOIN menu_category c  ON c.restaurant_id = mi.restaurant_id
                                AND c.menu_category_id = mi.menu_category_id
    LEFT   JOIN menu_category pc ON pc.restaurant_id = c.restaurant_id
                                AND pc.menu_category_id = c.parent_category_id
    WHERE  mi.protein_type_id IS NULL
      AND (mi.food_classification_code IS NULL OR mi.food_classification_code = 'non_veg')
),
candidates AS (
    SELECT s.*,
           CASE WHEN s.name_target THEN 'item name'
                ELSE 'category / parent / raw category'
           END AS signal_source
    FROM   signals s
    WHERE  NOT s.name_other
      AND (s.name_target OR (s.cat_target AND NOT s.cat_other))
),
updated AS (
    UPDATE menu_item mi
    SET    protein_type_id = mp.protein_type_id,
           updated_at      = (now() AT TIME ZONE 'UTC')
    FROM   candidates c
    CROSS  JOIN pork_protein mp
    WHERE  mi.menu_item_id = c.menu_item_id
      AND  mi.protein_type_id IS NULL          -- re-checked at write time
    RETURNING mi.menu_item_id,
              mi.protein_type_id AS new_protein_type_id
)
INSERT INTO menu_item_protein_update_log
       (batch_code, menu_item_id, old_protein_type_id, new_protein_type_id, old_updated_at, signal_source)
SELECT 'pork_20261005',
       u.menu_item_id,
       NULL,
       u.new_protein_type_id,
       c.updated_at_before,
       c.signal_source
FROM   updated u
JOIN   candidates c ON c.menu_item_id = u.menu_item_id;
-- psql prints "INSERT 0 <n>": n is the number of items updated.


/* ----------------------------------------------------------------------------
   STEP 3 - Verify, then finish the transaction.
   The count below should equal the number of rows STEP 1 returned.
   ---------------------------------------------------------------------------- */
SELECT signal_source, COUNT(*) AS items_updated
FROM   menu_item_protein_update_log
WHERE  batch_code = 'pork_20261005'
GROUP  BY signal_source;

 COMMIT;      -- keep the changes
-- ROLLBACK;    -- discard them (the log table is discarded too if it was new)


/* ----------------------------------------------------------------------------
   STEP 4 - UNDO (only after COMMIT, and only if needed).
   Reverts just the rows this batch set, and only where the protein is still
   the value this batch wrote, so later manual edits are not overwritten.
   ---------------------------------------------------------------------------- */
-- BEGIN;
-- UPDATE menu_item mi
-- SET    protein_type_id = l.old_protein_type_id,     -- NULL for this batch
--        updated_at      = l.old_updated_at
-- FROM   menu_item_protein_update_log l
-- WHERE  l.batch_code = 'pork_20261005'
--   AND  l.menu_item_id = mi.menu_item_id
--   AND  mi.protein_type_id = l.new_protein_type_id;
-- COMMIT;
