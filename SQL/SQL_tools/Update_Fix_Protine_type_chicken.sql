-- 0. Snapshot of the rows that could change, so you can undo later
CREATE TABLE menu_item_protein_backup_20261005 AS
SELECT menu_item_id, protein_type_id, updated_at
FROM   menu_item
WHERE  protein_type_id IS NULL;

BEGIN;

UPDATE menu_item mi
SET    protein_type_id = chk.protein_type_id,
       updated_at      = (now() AT TIME ZONE 'UTC')
FROM   protein_type chk
WHERE  UPPER(chk.code) = 'CHICKEN'
  AND  mi.protein_type_id IS NULL
  AND  mi.food_classification_code IS DISTINCT FROM 'veg'

  -- the item's own name must not name another protein
  AND  mi.name !~* '\y(mutton|lamb|gosht|fish|prawn|shrimp|crab|pork|beef|egg|anda|paneer)\y'

  AND (
        -- A. item name or any alias/translation says chicken
        mi.name ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y'
        OR EXISTS (SELECT 1
                   FROM   menu_item_name n
                   WHERE  n.menu_item_id = mi.menu_item_id
                     AND  n.name ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y')

        -- B. category / parent category / uncurated raw OCR category says chicken,
        --    and none of them names another protein
        OR (
            (
                EXISTS (SELECT 1
                        FROM   menu_category c
                        LEFT   JOIN menu_category pc
                               ON pc.restaurant_id = c.restaurant_id
                              AND pc.menu_category_id = c.parent_category_id
                        WHERE  c.restaurant_id = mi.restaurant_id
                          AND  c.menu_category_id = mi.menu_category_id
                          AND (c.name ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y'
                               OR COALESCE(pc.name, '') ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y'))
                OR (mi.menu_category_id IS NULL
                    AND COALESCE(mi.raw_category_text, '') ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y')
            )
            AND NOT EXISTS (SELECT 1
                            FROM   menu_category c
                            LEFT   JOIN menu_category pc
                                   ON pc.restaurant_id = c.restaurant_id
                                  AND pc.menu_category_id = c.parent_category_id
                            WHERE  c.restaurant_id = mi.restaurant_id
                              AND  c.menu_category_id = mi.menu_category_id
                              AND (c.name ~* '\y(mutton|lamb|gosht|fish|prawn|shrimp|crab|pork|beef|egg|anda|paneer)\y'
                                   OR COALESCE(pc.name, '') ~* '\y(mutton|lamb|gosht|fish|prawn|shrimp|crab|pork|beef|egg|anda|paneer)\y'))
            AND NOT (mi.menu_category_id IS NULL
                     AND COALESCE(mi.raw_category_text, '') ~* '\y(mutton|lamb|gosht|fish|prawn|shrimp|crab|pork|beef|egg|anda|paneer)\y')
        )
  );

-- psql prints "UPDATE <n>". If n looks plausible, spot-check a sample, then:
COMMIT;      -- or ROLLBACK;