/* ============================================================================
   KHAUSTAN.COM - DELETE ONE RESTAURANT                              (PostgreSQL)
   Database : KhaustanRestaurantMenu   (connect to it first; no \connect here)

   WHAT THIS DOES
     Permanently deletes ONE restaurant and everything that belongs to it:
     menu boards and their dated instances, categories, items, item names,
     variants, prices (all history), charges, availability, add-ons, bundles,
     bar items, tags, hours, holiday hours, phones, external ids, service modes,
     delivery set-up, media links and OCR / AI-extraction provenance.
     It also removes
       - rows in the shared tables media_asset, source_record and bar_product
         that ONLY this restaurant was using (anything another restaurant still
         references is kept), and
       - this restaurant's not-yet-published change_event_outbox rows
         (status pending / failed). No new outbox event is written.

   WHAT THIS NEVER TOUCHES
     establishment (kept even if it is left with no restaurant), brand,
     brand_menu_template / _board / _item, canonical_dish / _name, platform_tag,
     service_mode, protein_type, delivery_provider, bar_product_type,
     price_schedule / _day, every other restaurant (including siblings under the
     same establishment), and already-published outbox history.

   HOW TO RUN
     1. Replace the placeholder on the line marked INPUT with the numeric
        restaurant_id (a bare number, no quotes).
     2. Run the whole file. It is ONE transaction: any error rolls it all back.
     3. Read the NOTICE messages (rows deleted per table).
        DRY RUN: change the very last line from COMMIT to ROLLBACK.

   SAFETY
     - Unknown restaurant_id -> stops with an error, nothing is deleted.
     - Left unreplaced, the placeholder is a syntax error -> nothing runs.
     - If a row that belongs to ANOTHER restaurant points at this restaurant's
       data (bundle_component.component_menu_item_id, menu_item_addon_group,
       menu_board_instance_item.menu_item_id) the foreign key stops the delete,
       the error names the blocking row, and everything is rolled back.
     - Only KhaustanRestaurantMenu is touched. Reviews, search behaviour and any
       billing data elsewhere still hold this restaurant_id.
     - Image files in object storage are NOT removed; the script prints the
       storage_uri of every media_asset row it deletes so they can be removed.
     - Run it when nobody is editing this restaurant, and take a backup first:
       a committed delete cannot be undone.
   ============================================================================ */

BEGIN;

SET LOCAL search_path TO public;

DO $khaustan_delete$
DECLARE
    v_restaurant_id     BIGINT := 400070011;   -- INPUT  <<<  the only value to edit

    v_rest              restaurant%ROWTYPE;

    -- id sets belonging to this restaurant, captured before anything is deleted
    v_item_ids          BIGINT[];
    v_variant_ids       BIGINT[];
    v_price_ids         BIGINT[];
    v_board_ids         BIGINT[];
    v_instance_ids      BIGINT[];
    v_category_ids      BIGINT[];
    v_bundle_ids        BIGINT[];
    v_addon_group_ids   BIGINT[];
    v_batch_ids         BIGINT[];

    -- shared rows this restaurant used: candidates for clean-up (deleted only if now unreferenced)
    v_media_ids         BIGINT[];
    v_source_ids        BIGINT[];
    v_bar_product_ids   BIGINT[];

    v_n                 BIGINT;
    v_total             BIGINT := 0;
    v_uris              TEXT;
    v_remaining         BIGINT;
    v_err_msg           TEXT;
    v_err_detail        TEXT;
BEGIN
    -- ------------------------------------------------------------------
    -- 1. GUARD: the restaurant must exist. Lock its row so that nobody can
    --    attach new child rows while this script is running.
    -- ------------------------------------------------------------------
    SELECT * INTO v_rest
      FROM restaurant
     WHERE restaurant_id = v_restaurant_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'restaurant_id % does not exist in this database. Nothing was deleted.', v_restaurant_id
            USING ERRCODE = 'no_data_found';
    END IF;

    RAISE NOTICE 'Deleting restaurant_id % (%) - establishment_id % is kept.',
                 v_restaurant_id, v_rest.display_name, v_rest.establishment_id;
    RAISE NOTICE '    rows  table';

    -- ------------------------------------------------------------------
    -- 2. SNAPSHOT the id sets while every parent row still exists
    -- ------------------------------------------------------------------
    v_item_ids        := ARRAY(SELECT menu_item_id         FROM menu_item          WHERE restaurant_id = v_restaurant_id);
    v_variant_ids     := ARRAY(SELECT variant_id           FROM menu_item_variant  WHERE menu_item_id  = ANY(v_item_ids));
    v_price_ids       := ARRAY(SELECT price_id             FROM menu_item_price    WHERE variant_id    = ANY(v_variant_ids));
    v_board_ids       := ARRAY(SELECT menu_board_id        FROM menu_board         WHERE restaurant_id = v_restaurant_id);
    v_instance_ids    := ARRAY(SELECT board_instance_id    FROM menu_board_instance WHERE menu_board_id = ANY(v_board_ids));
    v_category_ids    := ARRAY(SELECT menu_category_id     FROM menu_category      WHERE restaurant_id = v_restaurant_id);
    v_bundle_ids      := ARRAY(SELECT bundle_id            FROM bundle             WHERE menu_item_id  = ANY(v_item_ids));
    v_addon_group_ids := ARRAY(SELECT addon_group_id       FROM addon_group        WHERE restaurant_id = v_restaurant_id);
    v_batch_ids       := ARRAY(SELECT extraction_batch_id  FROM menu_extraction_batch WHERE restaurant_id = v_restaurant_id);

    v_media_ids := ARRAY(
        SELECT media_asset_id FROM restaurant_media       WHERE restaurant_id        = v_restaurant_id
        UNION
        SELECT media_asset_id FROM menu_item_media        WHERE menu_item_id         = ANY(v_item_ids)
        UNION
        SELECT media_asset_id FROM menu_category_media    WHERE menu_category_id     = ANY(v_category_ids)
        UNION
        SELECT media_asset_id FROM menu_extraction_image  WHERE extraction_batch_id  = ANY(v_batch_ids));

    v_source_ids := ARRAY(
        SELECT source_id FROM menu_extraction_batch   WHERE extraction_batch_id = ANY(v_batch_ids)
        UNION
        SELECT source_id FROM menu_item_source        WHERE menu_item_id        = ANY(v_item_ids)
        UNION
        SELECT source_id FROM menu_item_price_source  WHERE price_id            = ANY(v_price_ids)
        UNION
        SELECT source_id FROM menu_item_price         WHERE price_id            = ANY(v_price_ids) AND source_id IS NOT NULL);

    v_bar_product_ids := ARRAY(
        SELECT bar_product_id FROM bar_menu_item         WHERE menu_item_id = ANY(v_item_ids) AND bar_product_id IS NOT NULL
        UNION
        SELECT bar_product_id FROM cocktail_base_option  WHERE cocktail_menu_item_id = ANY(v_item_ids));

    -- ------------------------------------------------------------------
    -- 3. OUTBOX: drop this restaurant's events that were never published,
    --    so the publisher does not relay changes for rows that no longer exist.
    --    Published history is left for the normal retention job.
    -- ------------------------------------------------------------------
    DELETE FROM change_event_outbox
     WHERE publish_status_code IN ('pending', 'failed')
       AND (   (aggregate_type = 'restaurant'        AND aggregate_id = v_restaurant_id)
            OR (aggregate_type = 'menu_item'         AND aggregate_id = ANY(v_item_ids))
            OR (aggregate_type = 'menu_item_variant'  AND aggregate_id = ANY(v_variant_ids))
            OR (aggregate_type = 'menu_item_price'    AND aggregate_id = ANY(v_price_ids))
            OR (aggregate_type = 'bundle'            AND aggregate_id = ANY(v_bundle_ids))
            OR (aggregate_type = 'menu_board'        AND aggregate_id = ANY(v_board_ids)));
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'change_event_outbox (pending/failed only)';

    -- ------------------------------------------------------------------
    -- 4. PRICES AND VARIANTS
    -- ------------------------------------------------------------------
    DELETE FROM menu_item_price_source WHERE price_id = ANY(v_price_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_item_price_source';

    DELETE FROM menu_item_price WHERE variant_id = ANY(v_variant_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_item_price';

    DELETE FROM menu_item_variant WHERE menu_item_id = ANY(v_item_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_item_variant';

    -- ------------------------------------------------------------------
    -- 5. OTHER MENU-ITEM CHILDREN
    -- ------------------------------------------------------------------
    DELETE FROM menu_item_charge WHERE menu_item_id = ANY(v_item_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_item_charge';

    DELETE FROM menu_item_availability WHERE menu_item_id = ANY(v_item_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_item_availability';

    DELETE FROM menu_item_availability_override WHERE menu_item_id = ANY(v_item_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_item_availability_override';

    DELETE FROM menu_item_name WHERE menu_item_id = ANY(v_item_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_item_name';

    DELETE FROM menu_item_tag WHERE menu_item_id = ANY(v_item_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_item_tag';

    DELETE FROM menu_item_media WHERE menu_item_id = ANY(v_item_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_item_media';

    DELETE FROM menu_item_source WHERE menu_item_id = ANY(v_item_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_item_source';

    DELETE FROM menu_item_delivery WHERE menu_item_id = ANY(v_item_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_item_delivery';

    DELETE FROM menu_item_addon_group WHERE menu_item_id = ANY(v_item_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_item_addon_group';

    -- ------------------------------------------------------------------
    -- 6. BUNDLES (combo / thali) AND BAR ITEMS
    -- ------------------------------------------------------------------
    DELETE FROM bundle_component WHERE bundle_id = ANY(v_bundle_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'bundle_component';

    DELETE FROM bundle_group WHERE bundle_id = ANY(v_bundle_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'bundle_group';

    DELETE FROM bundle WHERE menu_item_id = ANY(v_item_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'bundle';

    DELETE FROM cocktail_base_option WHERE cocktail_menu_item_id = ANY(v_item_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'cocktail_base_option';

    DELETE FROM bar_menu_item WHERE menu_item_id = ANY(v_item_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'bar_menu_item';

    -- ------------------------------------------------------------------
    -- 7. MENU BOARDS (and their dated instances)
    -- ------------------------------------------------------------------
    DELETE FROM menu_board_item WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_board_item';

    DELETE FROM menu_board_instance_item WHERE board_instance_id = ANY(v_instance_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_board_instance_item';

    DELETE FROM menu_board_category WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_board_category';

    DELETE FROM menu_board_instance WHERE menu_board_id = ANY(v_board_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_board_instance';

    DELETE FROM menu_board WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_board';

    -- ------------------------------------------------------------------
    -- 8. CATEGORIES AND ITEMS
    --    Items go before categories (an item points at its category).
    --    The category tree points at itself; one DELETE removes it whole.
    -- ------------------------------------------------------------------
    DELETE FROM menu_category_media WHERE menu_category_id = ANY(v_category_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_category_media';

    DELETE FROM category_text_alias WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'category_text_alias';

    DELETE FROM menu_item WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_item';

    DELETE FROM menu_category WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_category';

    -- ------------------------------------------------------------------
    -- 9. ADD-ONS
    -- ------------------------------------------------------------------
    DELETE FROM addon_option WHERE addon_group_id = ANY(v_addon_group_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'addon_option';

    DELETE FROM addon_group WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'addon_group';

    -- ------------------------------------------------------------------
    -- 10. OCR / AI-EXTRACTION PROVENANCE
    -- ------------------------------------------------------------------
    DELETE FROM menu_extraction_image WHERE extraction_batch_id = ANY(v_batch_ids);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_extraction_image';

    DELETE FROM menu_extraction_batch WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'menu_extraction_batch';

    -- ------------------------------------------------------------------
    -- 11. RESTAURANT-LEVEL ROWS
    -- ------------------------------------------------------------------
    DELETE FROM restaurant_media WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'restaurant_media';

    DELETE FROM restaurant_delivery_provider WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'restaurant_delivery_provider';

    DELETE FROM restaurant_delivery WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'restaurant_delivery';

    DELETE FROM restaurant_service_mode WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'restaurant_service_mode';

    DELETE FROM restaurant_hours WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'restaurant_hours';

    DELETE FROM restaurant_holiday_hours WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'restaurant_holiday_hours';

    DELETE FROM restaurant_tag WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'restaurant_tag';

    DELETE FROM restaurant_phone WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'restaurant_phone';

    DELETE FROM restaurant_external_identity WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'restaurant_external_identity';

    -- ------------------------------------------------------------------
    -- 12. THE RESTAURANT ITSELF (establishment and brand are not touched)
    -- ------------------------------------------------------------------
    DELETE FROM restaurant WHERE restaurant_id = v_restaurant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'restaurant';

    -- ------------------------------------------------------------------
    -- 13. SHARED ROWS THAT ONLY THIS RESTAURANT WAS USING
    --     Only rows this restaurant referenced are considered, and each is
    --     deleted only if nothing else references it now.
    -- ------------------------------------------------------------------
    WITH gone AS (
        DELETE FROM media_asset m
         WHERE m.media_asset_id = ANY(v_media_ids)
           AND NOT EXISTS (SELECT 1 FROM restaurant_media      x WHERE x.media_asset_id = m.media_asset_id)
           AND NOT EXISTS (SELECT 1 FROM menu_item_media       x WHERE x.media_asset_id = m.media_asset_id)
           AND NOT EXISTS (SELECT 1 FROM menu_category_media   x WHERE x.media_asset_id = m.media_asset_id)
           AND NOT EXISTS (SELECT 1 FROM menu_extraction_image x WHERE x.media_asset_id = m.media_asset_id)
        RETURNING m.media_asset_id, m.storage_uri)
    SELECT count(*), string_agg(storage_uri, E'\n    ' ORDER BY media_asset_id)
      INTO v_n, v_uris
      FROM gone;
    v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'media_asset (used only by this restaurant)';

    DELETE FROM source_record s
     WHERE s.source_id = ANY(v_source_ids)
       AND NOT EXISTS (SELECT 1 FROM menu_extraction_batch  x WHERE x.source_id = s.source_id)
       AND NOT EXISTS (SELECT 1 FROM menu_item_source       x WHERE x.source_id = s.source_id)
       AND NOT EXISTS (SELECT 1 FROM menu_item_price_source x WHERE x.source_id = s.source_id)
       AND NOT EXISTS (SELECT 1 FROM menu_item_price        x WHERE x.source_id = s.source_id);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'source_record (used only by this restaurant)';

    DELETE FROM bar_product b
     WHERE b.bar_product_id = ANY(v_bar_product_ids)
       AND NOT EXISTS (SELECT 1 FROM bar_menu_item        x WHERE x.bar_product_id = b.bar_product_id)
       AND NOT EXISTS (SELECT 1 FROM cocktail_base_option x WHERE x.bar_product_id = b.bar_product_id);
    GET DIAGNOSTICS v_n = ROW_COUNT;  v_total := v_total + v_n;  RAISE NOTICE '% %', lpad(v_n::text, 8), 'bar_product (used only by this restaurant)';

    -- ------------------------------------------------------------------
    -- 14. SUMMARY
    -- ------------------------------------------------------------------
    IF v_uris IS NOT NULL THEN
        RAISE NOTICE E'Remove these files from object storage (their media_asset rows are gone):\n    %', v_uris;
    END IF;

    SELECT count(*) INTO v_remaining FROM restaurant WHERE establishment_id = v_rest.establishment_id;
    RAISE NOTICE 'Done: % rows deleted for restaurant_id %. establishment_id % kept, % restaurant(s) remain under it.',
                 v_total, v_restaurant_id, v_rest.establishment_id, v_remaining;
    RAISE NOTICE 'Nothing is permanent until the COMMIT on the last line of this file.';

EXCEPTION
    WHEN foreign_key_violation THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_detail = PG_EXCEPTION_DETAIL;
        RAISE EXCEPTION 'Delete of restaurant_id % aborted and rolled back: a row outside this restaurant still points at its data. %',
                        v_restaurant_id, v_err_msg
            USING DETAIL = v_err_detail, ERRCODE = 'foreign_key_violation';
END
$khaustan_delete$;

COMMIT;   -- change to ROLLBACK for a dry run
