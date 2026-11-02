WITH params AS (
    SELECT (clock_timestamp() AT TIME ZONE 'UTC') AS now_utc
),

-- Aggregated per item up front so the multi-valued tables don't multiply rows.
item_names AS (
    SELECT min_.menu_item_id,
           string_agg(min_.name || ' (' || min_.language_code || ', ' || min_.name_type_code || ')',
                      ', ' ORDER BY min_.name_type_code, min_.language_code, min_.name) AS item_names_all
    FROM   menu_item_name min_
    JOIN   menu_item mi ON mi.menu_item_id = min_.menu_item_id
    WHERE  mi.restaurant_id = <<restaurant_id>>
    GROUP  BY min_.menu_item_id
),
item_tags AS (
    SELECT mit.menu_item_id,
           string_agg(pt.tag_code || COALESCE('=' || mit.value_text, ''),
                      ', ' ORDER BY pt.tag_code) AS item_tags
    FROM   menu_item_tag mit
    JOIN   menu_item mi    ON mi.menu_item_id = mit.menu_item_id
    JOIN   platform_tag pt ON pt.tag_id = mit.tag_id
    WHERE  mi.restaurant_id = <<restaurant_id>>
    GROUP  BY mit.menu_item_id
),
canonical_names AS (
    SELECT cdn.canonical_dish_id,
           string_agg(cdn.name || ' (' || cdn.language_code || ', ' || cdn.name_type_code || ')',
                      ', ' ORDER BY cdn.name_type_code, cdn.language_code, cdn.name) AS canonical_names_all
    FROM   canonical_dish_name cdn
    WHERE  cdn.canonical_dish_id IN (SELECT canonical_dish_id
                                     FROM   menu_item
                                     WHERE  restaurant_id = <<restaurant_id>>
                                       AND  canonical_dish_id IS NOT NULL)
    GROUP  BY cdn.canonical_dish_id
)

SELECT
    -- Menu item
    mi.menu_item_id,
    mi.name                       AS menu_item_name,
    mi.description                AS menu_item_description,
    n.item_names_all,
    mi.status_code                AS item_status,

    -- Category (and its parent, if any)
    c.menu_category_id,
    c.name                        AS category_name,
    pc.menu_category_id           AS parent_category_id,
    pc.name                       AS parent_category_name,
    mi.raw_category_text,         -- populated only while the item is still uncurated

    -- Variant
    v.variant_id,
    v.variant_name,
    v.variant_code,
    v.pricing_basis_code,
    v.quantity_value,
    v.quantity_unit_code,
    v.is_default                  AS variant_is_default,
    v.is_active                   AS variant_is_active,

    -- Price (current rows only; price rows have no name of their own,
    -- so service mode and schedule are the descriptive labels)
    p.price_id,
    p.price_amount,
    p.currency_code,
    p.is_market_price,
    sm.code                       AS service_mode_code,
    sm.name                       AS service_mode_name,
    ps.price_schedule_id,
    ps.name                       AS price_schedule_name,
    p.tax_regime_code,
    p.tax_inclusion_code,
    p.tax_rate,
    p.effective_from              AS price_effective_from,
    p.verification_status_code    AS price_verification_status,

    -- Canonical dish
    cd.canonical_dish_id,
    cd.canonical_name,
    cn.canonical_names_all,

    -- Protein / dietary
    mi.food_classification_code,
    prot.protein_type_id,
    prot.code                     AS protein_type_code,
    prot.label                    AS protein_type_label,
    dprot.label                   AS canonical_default_protein_label,
    mi.is_jain,                   -- NULL = not established, not "false"
    mi.is_vegan,
    mi.is_eggless,
    mi.spice_level,
    t.item_tags,                  -- halal, gluten_free, contains nuts etc. (absent = not asserted)

    -- Flags / other properties
    mi.is_bestseller,
    mi.is_recommended,
    mi.split_group_key,
    mi.inheritance_mode_code,
    mi.verification_status_code   AS item_verification_status,
    mi.last_verified_at           AS item_last_verified_at,
    b.bundle_id,
    b.bundle_type_code,
    (bmi.menu_item_id IS NOT NULL) AS is_bar_item,
    bmi.bar_item_type_code,
    bp.product_name               AS bar_product_name,
    bp.abv_percent

FROM   menu_item mi
CROSS  JOIN params
LEFT   JOIN menu_category c     ON c.restaurant_id = mi.restaurant_id
                               AND c.menu_category_id = mi.menu_category_id
LEFT   JOIN menu_category pc    ON pc.restaurant_id = c.restaurant_id
                               AND pc.menu_category_id = c.parent_category_id
LEFT   JOIN canonical_dish cd   ON cd.canonical_dish_id = mi.canonical_dish_id
LEFT   JOIN canonical_names cn  ON cn.canonical_dish_id = cd.canonical_dish_id
LEFT   JOIN protein_type prot   ON prot.protein_type_id = mi.protein_type_id
LEFT   JOIN protein_type dprot  ON dprot.protein_type_id = cd.default_protein_type_id
LEFT   JOIN item_names n        ON n.menu_item_id = mi.menu_item_id
LEFT   JOIN item_tags t         ON t.menu_item_id = mi.menu_item_id
LEFT   JOIN bundle b            ON b.menu_item_id = mi.menu_item_id
LEFT   JOIN bar_menu_item bmi   ON bmi.menu_item_id = mi.menu_item_id
LEFT   JOIN bar_product bp      ON bp.bar_product_id = bmi.bar_product_id
LEFT   JOIN menu_item_variant v ON v.menu_item_id = mi.menu_item_id
LEFT   JOIN menu_item_price p   ON p.variant_id = v.variant_id
                               AND p.effective_from <= params.now_utc
                               AND (p.effective_to IS NULL OR p.effective_to > params.now_utc)
LEFT   JOIN service_mode sm     ON sm.service_mode_id = p.service_mode_id
LEFT   JOIN price_schedule ps   ON ps.price_schedule_id = p.price_schedule_id

WHERE  mi.restaurant_id = <<restaurant_id>>

ORDER  BY pc.display_sequence NULLS FIRST,
          c.display_sequence  NULLS LAST,
          c.name,
          mi.name,
          mi.menu_item_id,
          v.display_sequence,
          v.variant_id,
          sm.code NULLS FIRST,
          ps.price_schedule_id NULLS FIRST;