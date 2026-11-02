SELECT
    mi.menu_item_id,
    mi.name                       AS menu_item_name,
    c.name                        AS category_name,
    pc.name                       AS parent_category_name,
    mi.raw_category_text,
    mi.food_classification_code,
    prot.code                     AS stored_protein_code,

    f.name_chicken,
    f.category_chicken,

    CASE
        WHEN f.name_chicken     THEN 'item name'
        WHEN f.category_chicken THEN 'category / parent category'
        ELSE NULL
    END                           AS chicken_signal_source,

    CASE
        WHEN mi.food_classification_code = 'veg'
            THEN 'ignore: classified veg'

        -- Item name mentions chicken
        WHEN f.name_chicken AND f.name_other
            THEN 'mixed proteins in name: review'
        WHEN f.name_chicken AND prot.code IS NULL
            THEN 'likely chicken (name), protein missing'
        WHEN f.name_chicken AND UPPER(prot.code) = 'CHICKEN'
            THEN 'consistent (name)'
        WHEN f.name_chicken
            THEN 'CONFLICT: name says chicken, protein is ' || prot.code

        -- Name is silent or says something else; the category says chicken
        WHEN f.category_chicken AND f.name_other
            THEN 'category says chicken, name says another protein: review'
        WHEN f.category_chicken AND f.category_other
            THEN 'category mixes proteins: review'
        WHEN f.category_chicken AND prot.code IS NULL
            THEN 'likely chicken (category), protein missing'
        WHEN f.category_chicken AND UPPER(prot.code) = 'CHICKEN'
            THEN 'consistent (category)'
        WHEN f.category_chicken
            THEN 'CONFLICT: category says chicken, protein is ' || prot.code

        -- No chicken signal anywhere
        WHEN UPPER(prot.code) = 'CHICKEN'
            THEN 'protein chicken, no name/category support (check)'
        ELSE 'no chicken signal'
    END                           AS verdict

FROM   menu_item mi
LEFT   JOIN menu_category c   ON c.restaurant_id = mi.restaurant_id
                             AND c.menu_category_id = mi.menu_category_id
LEFT   JOIN menu_category pc  ON pc.restaurant_id = c.restaurant_id
                             AND pc.menu_category_id = c.parent_category_id
LEFT   JOIN protein_type prot ON prot.protein_type_id = mi.protein_type_id
CROSS  JOIN LATERAL (
    SELECT
        -- item name or any alias/translation mentions chicken
        (   mi.name ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y'
         OR EXISTS (SELECT 1
                    FROM   menu_item_name n
                    WHERE  n.menu_item_id = mi.menu_item_id
                      AND  n.name ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y')
        )                                                              AS name_chicken,

        -- item name mentions a different protein
        (mi.name ~* '\y(mutton|lamb|gosht|fish|prawn|shrimp|crab|pork|beef|egg|anda|paneer)\y')
                                                                       AS name_other,

        -- category, parent category, or (if uncurated) raw OCR category text mentions chicken
        (   COALESCE(c.name,  '') ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y'
         OR COALESCE(pc.name, '') ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y'
         OR (mi.menu_category_id IS NULL
             AND COALESCE(mi.raw_category_text, '') ~* '\y(chicken|murgh|murg|kukkad|tangdi)\y')
        )                                                              AS category_chicken,

        -- category or parent also names another protein (e.g. "Chicken & Mutton")
        (   COALESCE(c.name,  '') ~* '\y(mutton|lamb|gosht|fish|prawn|shrimp|crab|pork|beef|egg|anda|paneer)\y'
         OR COALESCE(pc.name, '') ~* '\y(mutton|lamb|gosht|fish|prawn|shrimp|crab|pork|beef|egg|anda|paneer)\y'
        )                                                              AS category_other
) f

WHERE  mi.restaurant_id = <<restaurant_id>>

ORDER  BY verdict, c.name, mi.name;