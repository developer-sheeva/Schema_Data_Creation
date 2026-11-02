SELECT
    -- Menu item
    mi.menu_item_id,
    mi.name                       AS menu_item_name,
    mi.description                AS menu_item_description,
    (SELECT string_agg(min_.name || ' (' || min_.language_code || ', ' || min_.name_type_code || ')',
                       ', ' ORDER BY min_.name_type_code, min_.language_code, min_.name)
     FROM   menu_item_name min_
     WHERE  min_.menu_item_id = mi.menu_item_id)           AS item_names_all,
    mi.status_code                AS item_status,
    mi.raw_category_text,

    cd.canonical_dish_id,
    cd.canonical_name,
    (SELECT string_agg(cdn.name || ' (' || cdn.language_code || ', ' || cdn.name_type_code || ')',
                       ', ' ORDER BY cdn.name_type_code, cdn.language_code, cdn.name)
     FROM   canonical_dish_name cdn
     WHERE  cdn.canonical_dish_id = cd.canonical_dish_id)  AS canonical_names_all,

    -- Protein / dietary
    mi.food_classification_code,
    prot.protein_type_id,
    prot.code                     AS protein_type_code,
    prot.label                    AS protein_type_label,
    dprot.label                   AS canonical_default_protein_label,
    mi.is_jain,
    mi.is_vegan,
    mi.is_eggless,
    mi.spice_level,
    (SELECT string_agg(pt.tag_code || COALESCE('=' || mit.value_text, ''),
                       ', ' ORDER BY pt.tag_code)
     FROM   menu_item_tag mit
     JOIN   platform_tag pt ON pt.tag_id = mit.tag_id
     WHERE  mit.menu_item_id = mi.menu_item_id)            AS item_tags,

    mi.is_bestseller,
    mi.is_recommended,
    mi.split_group_key,
    mi.inheritance_mode_code,
    mi.verification_status_code   AS item_verification_status,
    mi.last_verified_at           AS item_last_verified_at--,

FROM   menu_item mi
JOIN   protein_type prot        ON prot.protein_type_id = mi.protein_type_id
                               AND UPPER(prot.code) = 'CHICKEN'
LEFT   JOIN canonical_dish cd   ON cd.canonical_dish_id = mi.canonical_dish_id
LEFT   JOIN protein_type dprot  ON dprot.protein_type_id = cd.default_protein_type_id

WHERE  mi.restaurant_id = 400070012

ORDER  BY mi.name,
          mi.menu_item_id
		  ;