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