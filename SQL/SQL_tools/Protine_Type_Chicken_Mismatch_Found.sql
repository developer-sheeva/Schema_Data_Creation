SELECT
    mi.menu_item_id,
    mi.name                         AS menu_item_name,
    mi.food_classification_code,
    prot.code                       AS stored_protein_code,

    -- Does the name (or any alias/translation) look like chicken?
    (   mi.name ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y'
     OR EXISTS (SELECT 1
                FROM   menu_item_name n
                WHERE  n.menu_item_id = mi.menu_item_id
                  AND  n.name ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y')
    )                               AS name_suggests_chicken,

    CASE
        WHEN mi.food_classification_code = 'veg'
            THEN 'ignore: classified veg (mock-meat name?)'
        WHEN (mi.name ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y'
              OR EXISTS (SELECT 1 FROM menu_item_name n
                         WHERE n.menu_item_id = mi.menu_item_id
                           AND n.name ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y'))
             AND prot.code IS NULL
            THEN 'likely chicken, protein missing'
        WHEN (mi.name ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y'
              OR EXISTS (SELECT 1 FROM menu_item_name n
                         WHERE n.menu_item_id = mi.menu_item_id
                           AND n.name ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y'))
             AND UPPER(prot.code) <> 'CHICKEN'
            THEN 'CONFLICT: name says chicken, protein is ' || prot.code
        WHEN UPPER(prot.code) = 'CHICKEN'
             AND NOT (mi.name ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y')
            THEN 'protein chicken, name does not say so (check)'
        ELSE 'consistent'
    END                             AS verdict
FROM   menu_item mi
LEFT   JOIN protein_type prot ON prot.protein_type_id = mi.protein_type_id
WHERE  mi.restaurant_id = <<restaurant_id>>
ORDER  BY verdict, mi.name;