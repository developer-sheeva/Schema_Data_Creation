/* ============================================================================
   KhaustanRestaurantMenu -- merge exact-duplicate canonical_dish rows
   PostgreSQL. Run against the KhaustanRestaurantMenu database only.

   WHAT IT DOES
     Rows in canonical_dish that share the same normalized_name are collapsed
     into ONE surviving row. Everything that pointed at a duplicate is
     repointed to the survivor:
        - menu_item.canonical_dish_id
        - brand_menu_template_item.canonical_dish_id
        - canonical_dish_name rows (duplicate names are dropped first so the
          uq_canonical_dish_name constraint is not violated)

   WHAT IT DELIBERATELY DOES NOT DO
     Groups whose rows genuinely disagree (different food_classification_code,
     default_protein_type_id, is_jain, is_vegan or is_eggless -- ignoring
     NULLs) are NOT merged. They show as REVIEW in the preview so a human
     decides. NULL means "not established", so a NULL never blocks a merge;
     the survivor simply inherits the non-NULL value from the group.

   HOW TO RUN
     1. Run SECTION A (read-only) and look at the MERGE / REVIEW groups.
     2. Run SECTION B once with the final line changed to ROLLBACK to see the
        verification output without changing anything (all DDL is
        transactional in PostgreSQL, so ROLLBACK undoes the map table too).
     3. Run SECTION B again with COMMIT.
     4. When no REVIEW groups remain, run SECTION C (unique index).

   canonical_dish_merge_map is kept on purpose. KhaustanReviews and
   KhaustanSearchBehavior are separate databases and may hold canonical_dish_id
   values as plain BIGINTs (no FK possible). Use the map to repoint those:
   old_canonical_dish_id -> new_canonical_dish_id. Drop it once they are done.
   ============================================================================ */


/* ============================================================================
   SECTION A -- PREVIEW (read-only)
   ============================================================================ */
SELECT cd.normalized_name,
       COUNT(*)                                                         AS dish_rows,
       string_agg(cd.canonical_dish_id::text, ', '
                  ORDER BY cd.canonical_dish_id)                        AS dish_ids,
       string_agg(DISTINCT cd.food_classification_code, ', ')            AS classifications,
       COUNT(DISTINCT cd.default_protein_type_id)                       AS n_protein_types,
       COUNT(DISTINCT cd.is_jain)                                       AS n_jain_values,
       COUNT(DISTINCT cd.is_vegan)                                      AS n_vegan_values,
       COUNT(DISTINCT cd.is_eggless)                                    AS n_eggless_values,
       CASE WHEN COUNT(DISTINCT cd.food_classification_code) <= 1
             AND COUNT(DISTINCT cd.default_protein_type_id)  <= 1
             AND COUNT(DISTINCT cd.is_jain)                  <= 1
             AND COUNT(DISTINCT cd.is_vegan)                 <= 1
             AND COUNT(DISTINCT cd.is_eggless)               <= 1
            THEN 'MERGE' ELSE 'REVIEW' END                              AS action
FROM canonical_dish cd
GROUP BY cd.normalized_name
HAVING COUNT(*) > 1
ORDER BY action, dish_rows DESC, cd.normalized_name;

-- Summary: how many rows disappear if every MERGE group is merged.
SELECT COUNT(*) AS canonical_dish_rows_now,
       COUNT(DISTINCT normalized_name) AS rows_after_full_exact_merge
FROM canonical_dish;


/* ============================================================================
   SECTION B -- MERGE (single transaction)
   ============================================================================ */
BEGIN;

CREATE TABLE IF NOT EXISTS canonical_dish_merge_map (
    old_canonical_dish_id   BIGINT NOT NULL PRIMARY KEY,
    new_canonical_dish_id   BIGINT NOT NULL,
    merged_at               TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL
                            DEFAULT (clock_timestamp() AT TIME ZONE 'UTC')
);

-- B1. Build the map: every non-surviving row -> its survivor. The survivor is
--     the row with a known classification, then a known protein type, then
--     the lowest id.
WITH safe_groups AS (
    SELECT normalized_name
    FROM canonical_dish
    GROUP BY normalized_name
    HAVING COUNT(*) > 1
       AND COUNT(DISTINCT food_classification_code) <= 1
       AND COUNT(DISTINCT default_protein_type_id)  <= 1
       AND COUNT(DISTINCT is_jain)                  <= 1
       AND COUNT(DISTINCT is_vegan)                 <= 1
       AND COUNT(DISTINCT is_eggless)               <= 1
),
ranked AS (
    SELECT cd.canonical_dish_id,
           cd.normalized_name,
           ROW_NUMBER() OVER (PARTITION BY cd.normalized_name
                              ORDER BY (cd.food_classification_code IS NULL),
                                       (cd.default_protein_type_id  IS NULL),
                                       cd.canonical_dish_id) AS rn
    FROM canonical_dish cd
    JOIN safe_groups g ON g.normalized_name = cd.normalized_name
)
INSERT INTO canonical_dish_merge_map (old_canonical_dish_id, new_canonical_dish_id)
SELECT l.canonical_dish_id, s.canonical_dish_id
FROM ranked l
JOIN ranked s ON s.normalized_name = l.normalized_name AND s.rn = 1
WHERE l.rn > 1
ON CONFLICT (old_canonical_dish_id) DO NOTHING;

-- B2. Let each survivor inherit values it was missing from its duplicates.
--     Safe because groups with conflicting non-NULL values were excluded.
UPDATE canonical_dish s
SET description              = COALESCE(s.description, x.description),
    food_classification_code = COALESCE(s.food_classification_code, x.food_classification_code),
    default_protein_type_id  = COALESCE(s.default_protein_type_id, x.default_protein_type_id),
    is_jain                  = COALESCE(s.is_jain, x.is_jain),
    is_vegan                 = COALESCE(s.is_vegan, x.is_vegan),
    is_eggless               = COALESCE(s.is_eggless, x.is_eggless),
    updated_at               = (clock_timestamp() AT TIME ZONE 'UTC')
FROM (
    SELECT m.new_canonical_dish_id            AS survivor_id,
           MAX(l.description)                 AS description,
           MAX(l.food_classification_code)    AS food_classification_code,
           MAX(l.default_protein_type_id)     AS default_protein_type_id,
           bool_or(l.is_jain)                 AS is_jain,
           bool_or(l.is_vegan)                AS is_vegan,
           bool_or(l.is_eggless)              AS is_eggless
    FROM canonical_dish_merge_map m
    JOIN canonical_dish l ON l.canonical_dish_id = m.old_canonical_dish_id
    GROUP BY m.new_canonical_dish_id
) x
WHERE s.canonical_dish_id = x.survivor_id;

-- B3a. Drop name rows that would collide once moved onto the survivor
--      (the survivor's own rows win, then the lowest name id).
WITH affected AS (
    SELECT n.canonical_dish_name_id,
           COALESCE(m.new_canonical_dish_id, n.canonical_dish_id) AS target_id,
           (m.new_canonical_dish_id IS NULL)                      AS is_survivor_row,
           n.language_code, n.name_type_code, n.name
    FROM canonical_dish_name n
    LEFT JOIN canonical_dish_merge_map m ON m.old_canonical_dish_id = n.canonical_dish_id
    WHERE COALESCE(m.new_canonical_dish_id, n.canonical_dish_id)
          IN (SELECT new_canonical_dish_id FROM canonical_dish_merge_map)
),
ranked AS (
    SELECT canonical_dish_name_id,
           ROW_NUMBER() OVER (PARTITION BY target_id, language_code, name_type_code, name
                              ORDER BY is_survivor_row DESC, canonical_dish_name_id) AS rn
    FROM affected
)
DELETE FROM canonical_dish_name
WHERE canonical_dish_name_id IN (SELECT canonical_dish_name_id FROM ranked WHERE rn > 1);

-- B3b. Move the remaining name rows to the survivor.
UPDATE canonical_dish_name n
SET canonical_dish_id = m.new_canonical_dish_id
FROM canonical_dish_merge_map m
WHERE n.canonical_dish_id = m.old_canonical_dish_id;

-- B4. Repoint everything else that referenced a duplicate.
UPDATE menu_item mi
SET canonical_dish_id = m.new_canonical_dish_id
FROM canonical_dish_merge_map m
WHERE mi.canonical_dish_id = m.old_canonical_dish_id;

UPDATE brand_menu_template_item ti
SET canonical_dish_id = m.new_canonical_dish_id
FROM canonical_dish_merge_map m
WHERE ti.canonical_dish_id = m.old_canonical_dish_id;

-- B5. Delete the duplicates. If anything still references one, the foreign
--     key makes this statement fail and the whole transaction is undone.
DELETE FROM canonical_dish cd
USING canonical_dish_merge_map m
WHERE cd.canonical_dish_id = m.old_canonical_dish_id;

-- B6. Verification.
SELECT COUNT(*) AS rows_merged_away FROM canonical_dish_merge_map;

-- Only REVIEW groups (genuine conflicts) should be left here.
SELECT normalized_name, COUNT(*) AS dish_rows
FROM canonical_dish
GROUP BY normalized_name
HAVING COUNT(*) > 1
ORDER BY dish_rows DESC, normalized_name;

-- First run: change COMMIT to ROLLBACK to inspect without changing anything.
COMMIT;


/* ============================================================================
   SECTION C -- prevent recurrence (run only when Section B's second
   verification query returns no rows)
   ============================================================================ */
-- CREATE UNIQUE INDEX uq_canonical_dish_normalized_name ON canonical_dish(normalized_name);
-- DROP INDEX IF EXISTS ix_canonical_dish_normalized;   -- now redundant
