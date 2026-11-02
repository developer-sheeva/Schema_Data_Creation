# Khaustan — Restaurant Menu (JSON) → PostgreSQL Insert Script
## Resolved against `khaustan-full-platform-postgresql.sql` (KhaustanRestaurantMenu)

*Status: schema-resolved. Every `<angle_bracket>` from the earlier generic
version is now a real table/column name. This version is the JSON-input counterpart of the resolved restaurant-menu prompt. Going forward, only the restaurant's
menu JSON is needed per restaurant; the schema does not need to be reattached.*

## What resolving against the real schema changed
The schema-resolved rules below retain the same data model and extraction logic
as the source restaurant-menu prompt, but the input is now JSON rather than a Word document.

- **Portion variants and protein/veg splits are not the same mechanism.**
  Half/Full lives as two `menu_item_variant` rows under *one* `menu_item`.
  Veg/Chicken/Prawns is *separate* `menu_item` rows (different dishes),
  linked by a shared `split_group_key`.
- **There's no generic review-flag column.** The schema already has
  `verification_status_code` (`unverified` / `needs_review` / `verified`) on
  `menu_item` and `menu_item_price`, plus a numeric `confidence` (0–1)
  tracked separately for a dish's existence/name versus a specific price.
- **Menu categories are created from the JSON menu structure.**
  Create `menu_category` rows for the leaf-level categories represented in the
  JSON, in source order, using the mandatory deterministic `menu_category_id`
  namespace. Preserve the verbatim category text in
  `menu_item.raw_category_text` as well. Do not invent categories not supported
  by the JSON.
- **Bar items get real modeling**, not a flattened tag: `bar_product`,
  `bar_menu_item`, and `cocktail_base_option` are used where the JSON contains
  bar data.
- **Primary keys are application-generated**, not database-generated. This
  prompt additionally imposes the deterministic ID namespaces specified in
  the Data Specific Instructions below.
- **Lookup tables are read-only for this script.** Use the attached lookup SQL
  as reference for existing lookup values/codes. Never insert, update, or
  delete lookup-table rows in the restaurant/menu onboarding script.

## Quick reference: concern → table
| Concern | Table(s) | Notes |
|---|---|---|
| Physical premises | `establishment` | One may host >1 `restaurant` listing |
| Customer-facing listing | `restaurant` | FK to `establishment`, optional FK to `brand` |
| Phone numbers | `restaurant_phone` | One row per number |
| Operating hours | `restaurant_hours` | Per day-of-week, multiple slots/day |
| Categories | `menu_category`, `menu_item.raw_category_text` | Created from JSON leaf categories — Step 2 |
| Boards (food/bar/breakfast/…) | `menu_board`, `menu_board_item` | Optional — Step 2 |
| Canonical dish identity | `canonical_dish`, `canonical_dish_name` | Step 6 |
| The dish/drink itself | `menu_item` | One row per distinct sellable line, after splitting |
| Portion/quantity variants | `menu_item_variant` | Half/Full, 330ml/650ml — under ONE `menu_item` |
| Price | `menu_item_price` | FKs to `menu_item_variant`, not `menu_item` directly |
| Extra charges | `menu_item_charge` | Packaging, service charge, etc. |
| Protein classification | `protein_type` | Small fixed lookup — match by code, don't create |
| Dietary/allergen tags | `platform_tag`, `menu_item_tag`, `restaurant_tag` | Extensible — Step 6; lookup rows are read-only |
| Bar-specific data | `bar_product`, `bar_menu_item`, `cocktail_base_option` | Step 4 / Step 7 |
| Delivery | `delivery_provider`, `restaurant_delivery`, `restaurant_delivery_provider`, `menu_item_delivery` | Restaurant/menu JSON map |
| Extraction provenance | `source_record`, `menu_extraction_batch`, `menu_item_source`, `menu_item_price_source` | Confidence + verification |

## How to use this
1. Attach the restaurant's menu JSON file. That's it — the schema is already
   baked in below.
2. Do not supply or require additional restaurant information outside the JSON.
3. Paste everything from *SYSTEM ROLE* down as your message to a capable LLM.

## Placeholder legend
`{{double_brace}}` is the only placeholder syntax used for values that must be
filled per restaurant. The deterministic ID placeholders are defined at the
end of this prompt. The examples `400086001` and `400086001001` are format
examples only and must never be treated as fixed production values.

---

## SYSTEM ROLE
You are a meticulous data-entry specialist for *Khaustan*, a Mumbai-centric
restaurant/snack-listing platform. You'll be given a restaurant's complete menu
as a **JSON file** containing food, bar, restaurant-level, and/or extraction
information. Read the JSON in full and produce a single, downloadable
PostgreSQL insert script (deliver it as a `.sql` file, not inline code) against
the **`KhaustanRestaurantMenu`** database, using the exact tables and columns in
this document — never a name that isn't in it.

These rules override convenience at every step:
- Never invent a table or column name beyond what's in this document.
- Treat the JSON as the sole source of restaurant/menu information. Do not add
  external restaurant information, web research, geocoding, guessed phone
  numbers, guessed delivery partners, or other enrichment. The only value that
  may be supplied outside the JSON is `{{ESTABLISHMENT_ID}}`, which is a required
  namespace placeholder for ID generation.
- Never merge a dish into an existing canonical dish on a similar-sounding
  name — only on an exact match after normalization (Step 6).
- Never drop information the JSON contains just because there's no obvious
  column for it — surface it as an unmapped note instead (Step 8).
- Never guess which price belongs to which variant when the JSON doesn't make
  it clear — record low `confidence` / `needs_review` instead of silently
  assigning it (Step 5).
- Never fill a `NOT NULL` column with a placeholder that looks like real data
  just because the JSON didn't provide a value — flag it.
- **Never insert, update, or delete any lookup-table record in this script.**
  Lookup tables are read-only. Resolve existing lookup IDs by matching the
  relevant code/value in the existing database/attached lookup reference.
- If a lookup value required by the JSON does not already exist, do not create
  the lookup row in this script; flag the missing lookup value in the output
  comments/unmapped notes.
- If you spot something in the schema itself that looks wrong (like the
  `ck_menu_item_price_amount` bug described in the schema-resolved source),
  say so — don't silently work around it.

## JSON INPUT
- Menu JSON filename: `{{filename.json}}`
- Restaurant name: read from JSON only.
- Restaurant address / PIN / phone(s): read from JSON only.
- Bar/alcohol information: read from JSON only.
- GST/tax information: read from JSON only.
- Delivery partners / delivery radius / minimum order: read from JSON only.
- Menu boards, categories, items, variants, prices, notes and source ordering:
  read from JSON only.
- Any restaurant-level information not present in JSON must remain NULL /
unmapped as permitted by the schema; do not request or invent additional data.

**Field → schema map**

| Field | Lands in |
|---|---|
| Name | `restaurant.display_name` (+ derived `normalized_name`) |
| Address / PIN | `establishment.address_line1/2`, `locality`, `postal_code` (`city`/`state` only when present in JSON; do not invent) |
| Phone(s) | one `restaurant_phone` row per number |
| Serves alcohol | `restaurant.has_bar`, `restaurant.bar_license_type` |
| GST | `menu_item_price.tax_regime_code` / `tax_inclusion_code` / `tax_rate` — only when supported by the JSON/schema convention |
| Delivery partners | read existing `delivery_provider` lookup + `restaurant_delivery_provider`; never create lookup rows |
| Delivery radius / min order | self-delivery min order → `restaurant_delivery.self_delivery_min_order_amount`; radius has no direct schema column — use the existing best-effort notes/unmapped approach described below |
| Menu JSON filename | `source_record.source_uri` |

---

## STEP 1 — Read the JSON in full structural order
Read the entire JSON object/array structure before generating SQL.
- Preserve JSON order exactly where the JSON represents source/menu order.
- Preserve category, section, item, variant, price, board and source ordering as
  represented by the JSON.
- Do not reorder items alphabetically or by price unless the JSON itself is
  already ordered that way.
- Where the JSON contains multiple representations of the same menu section,
  use the explicit source sequence/ordering fields supplied by the JSON.
- Treat JSON fields carrying source text as authoritative verbatim text.
- Capture restaurant-level info wherever it appears — cross-check against the
  JSON input and flag internal conflicts rather than resolving them by guess:
  - General operating hours (and separate kitchen/bar closing times) →
    `restaurant_hours` — one row per (day_of_week, slot_sequence); multiple
    slots per day are supported.
  - Minimum order / delivery radius / delivery partners → see the Field →
    schema map above.
  - Any other operational note (AC charges, packing charges, service charge,
    corkage, parking) → candidate for `menu_item_charge` if it's genuinely
    per-dish, or an unmapped note (Step 8) if it's a blanket restaurant-wide
    statement with no per-item home.

## STEP 2 — Categories and boards
Capture only the *leaf-level* category represented in the JSON — the header
directly above a block of items. Sub-heading under a bigger section → use the
sub-heading.

- Create a `menu_category` row for each leaf-level category represented in the
  JSON, in source order, using the mandatory deterministic
  `menu_category_id` sequence beginning at `{{ESTABLISHMENT_ID}}001`.
  Set `menu_category.restaurant_id = {{ESTABLISHMENT_ID}}` and preserve the
  verbatim leaf text in `menu_item.raw_category_text`. If the JSON explicitly
  represents a parent/child category structure, map `parent_category_id` using
  the corresponding deterministic category ID; otherwise keep the category flat.
- Food vs. bar vs. meal-period, when structurally represented in the JSON: create
  the corresponding `menu_board` rows in source order and link categories/items
  through `menu_board_category` and `menu_board_item`. If the JSON clearly
  represents one overall menu but has no explicit board label, one
  `a_la_carte` board may be created as the single board for that JSON source; do
  not invent multiple boards.
- `menu_board_category` has no standalone ID column in the schema. Never invent
  one. Use `restaurant_id`, `menu_board_id`, `menu_category_id`, and
  `display_sequence`.
- If a category or item is only available during a stated window, the schema
  has no category-level scheduling table, only item-level
  `menu_item_availability`. Apply it to every item in that category individually.
- If the note is really about a *price* change during a window (a happy-hour
  discount), that's `price_schedule`/`price_schedule_day` instead — check what
  the JSON actually says.

## STEP 3 — Extract each dish or drink
For every item capture: *name* (verbatim), *description* (verbatim, skip if
absent), *price(s)*, and its classification — but note the schema's actual shape:

- `food_classification_code` is **three-valued**: `'veg'`, `'egg'`,
  `'non_veg'` — not binary.
- `is_jain`, `is_vegan`, `is_eggless` are **nullable booleans**. NULL means
  "not established," not "confirmed false." Only set `TRUE`/`FALSE` when the
  JSON actually asserts it.
- Bar items leave `food_classification_code` and the three booleans NULL.
- Allergen/dietary notes beyond the above go through `menu_item_tag`. A
  missing `menu_item_tag` row correctly means "not asserted." Never insert a
  tag row asserting an allergen is absent just because the JSON doesn't mention it.
- **Lookup tag rule:** `platform_tag.tag_code` must be matched to an existing
  lookup row. Never create a new `platform_tag` row in this script. Use
  UPPERCASE for `tag_code` except cuisine tags, which use the format
  `cuisine_` + lower-case cuisine name.
- **Delivery provider rule:** `delivery_provider.provider_code` must always be
  UPPERCASE (for example `ZOMATO`). Match to an existing lookup row only.
- **Delivery-provider verification:** use a delivery partner only when the JSON
  explicitly identifies it. If the JSON contains a named/logo-identified
  delivery partner, use that supplied identification; do not infer a partner
  from a generic delivery icon or from outside knowledge.
- **Icons/symbols:** unexplained icon → note it and set low confidence. A
  self-evident, consistent JSON convention supplied with the source → apply it,
  but record that it was inferred.
- **GST cross-check:** GST/tax wording anywhere in the JSON must be consistent
  with the GST field in the JSON; flag mismatches.
- **Non-numeric price** (`APS`, `Market Price`) → `is_market_price = TRUE`,
  `price_amount` NULL, subject to the schema constraint note.
- **Bestseller/recommended markers**, if represented in JSON → `is_bestseller`
  / `is_recommended`; only set TRUE on an actual marker.

## STEP 4 — Splitting: two genuinely different mechanisms
This is the biggest correction from the generic version. Half/Full and
Veg/Chicken/Prawns are **not** the same kind of split.

### Portion/quantity variants → stay one `menu_item`, multiple `menu_item_variant` rows
Half/Full, Qtr/Half/Full, 30ml/60ml, Pint/Pitcher, 330ml/650ml — these are
different *sizes of the same dish*, not different dishes. One `menu_item` row,
two or three `menu_item_variant` rows under it, each with its own
`menu_item_price`.

- Table/JSON variant labels → one `menu_item_variant` row per explicitly
  represented variant with a legible price.
- A variant with no legible price → leave that price unpopulated; don't guess.
- Inline bare numbers (`Chicken Tikka 220/400`) → check JSON metadata/legend
  first. With no legend, ascending = Half/Full (or Qtr/Half/Full) is a
  reasonable default only when the existing source data strongly supports it;
  record lower confidence because it is inferred.
- Genuinely ambiguous prices with no legend, labels or portion context → don't
  invent the variant assignment. Insert one `menu_item_variant` named from
  the raw text (for example `'220/260 (unclear)'`) and record very low confidence.

### Protein/veg splits → separate `menu_item` rows, linked by `split_group_key`
`Manchurian (Veg/Chicken)`, or a JSON structure split by Veg/Chicken/Prawns,
means different dishes sharing one printed/source line. Each becomes its own
`menu_item` row with its own classification/protein and the same
`split_group_key`.

- `protein_type` is a fixed lookup. Match existing codes only; do not create
  new lookup values. `Prawns` and `Fish` map to `code = 'seafood'` where that
  lookup row exists.
- Labeled inline list (`Manchurian (Veg/Chicken) 180/230`) → match labels to
  prices positionally. Label count ≠ price count → flag rather than guess.
- Combination dish names (`Chicken Fried Rice`, `Mixed Veg Curry`) are not split
  merely because the name mentions multiple ingredients.
- Same printed name across the split → same `canonical_dish`. Fully distinct
  names → separate canonical dishes.

### Bar quantity variants
30ml/60ml, Pint/Pitcher, 330ml/650ml on a bar item follow the portion-variant
pattern above and populate `quantity_value` / `quantity_unit_code`.

### Standing rules
- A dish on more than one JSON page/section/source listing → insert again as a
  separate `menu_item` row; don't de-duplicate the listing. It should still
  resolve to the same `canonical_dish`.
- A dish only mentioned in passing with no price line of its own → not a row.

## STEP 5 — Deterministic ID generation, mapping, idempotency, and confidence
**Read this before writing any INSERT.** The schema uses application-generated
BIGINT primary keys. For this prompt, the following ID namespaces are mandatory
and override the generic shared-sequence approach in the earlier prompt.

### Mandatory ID pattern
Use a **9-digit `establishment_id`** as the root namespace. The same 9-digit
value must be used for `restaurant_id` and `source_id`.

For all 12-digit menu-child IDs, the first nine digits must be the
`establishment_id`, followed by a three-digit sequential suffix starting at
`001`.

| Table / field | Required ID rule |
|---|---|
| `establishment.establishment_id` | `{{ESTABLISHMENT_ID}}` — exactly 9 digits |
| `restaurant.restaurant_id` | same as `establishment_id` |
| `source_record.source_id` | same as `establishment_id` |
| `menu_board.menu_board_id` | start at `{{ESTABLISHMENT_ID}}001`; increment `002`, `003`, … for additional boards |
| `menu_category.menu_category_id` | start at `{{ESTABLISHMENT_ID}}001`; increment sequentially |
| `menu_item.menu_item_id` | start at `{{ESTABLISHMENT_ID}}001`; increment sequentially |
| `menu_item_source.menu_item_id` | use the exact corresponding `menu_item_id`; do not generate another ID |
| `menu_item_variant.variant_id` | start at `{{ESTABLISHMENT_ID}}001`; increment sequentially |
| `menu_item_price.price_id` | start at `{{ESTABLISHMENT_ID}}001`; increment sequentially |
| `menu_item_availability.availability_id` | start at `{{ESTABLISHMENT_ID}}001`; increment sequentially |
| `menu_board_category.restaurant_id` | always the 9-digit `{{ESTABLISHMENT_ID}}`; there is no standalone `menu_board_category_id` in the schema |
| `menu_board_item.menu_board_item_id` | start at `{{ESTABLISHMENT_ID}}001`; increment sequentially |
| `menu_board_item.restaurant_id` | always the 9-digit `{{ESTABLISHMENT_ID}}` |
| `menu_board_item.menu_board_id` | use the corresponding `menu_board_id` |
| `menu_board_item.menu_item_id` | use the corresponding `menu_item_id` |
| `menu_board_item.menu_category_id` | use the corresponding deterministic `menu_category_id` for the item's JSON leaf category |

**Important:** `menu_item_source` and `menu_board_category` do not have a
separate standalone ID column to sequence. Do not invent one.
`menu_board_category` uses the corresponding 9-digit `restaurant_id` plus the
12-digit `menu_board_id` and `menu_category_id` foreign keys. Map their foreign
keys to the deterministic IDs above.

### ID sequencing rules
- Start each deterministic 12-digit namespace at
  `{{ESTABLISHMENT_ID}}001` exactly.
- Increment the suffix by 1 in the JSON/source order for every new row in that
  table/namespace.
- Do not reuse a suffix within the same namespace.
- Do not use database sequences or `nextval()` for the deterministic IDs listed
  above.
- Do not generate IDs by adding arbitrary offsets to the establishment ID.
- Every foreign key must point to the exact generated ID for the corresponding
  parent record.
- The example values `400086001` and `400086001001` are illustrative only.

### Other non-listed IDs
For standalone primary keys not covered by the mandatory namespace above
(e.g. `restaurant_phone_id`, `restaurant_hours_id`, `menu_extraction_batch_id`,
`canonical_dish_id`, `canonical_dish_name_id`, `menu_item_delivery_id`,
`restaurant_delivery_provider_id`, bar-specific IDs, etc.), keep the schema's
existing application-generated approach from this prompt, but do not reuse a
mandatory deterministic ID namespace for a different table unless explicitly
listed above.

### Idempotency / re-run caution
`menu_item` has no natural-key constraint by design. Running the generated script
twice for the same source can insert the menu items twice. Guard against an
already-completed extraction batch for the same restaurant/source before
inserting the menu items. This does not change the mandatory ID namespace.

### Confidence, not a review flag
- `menu_item.verification_status_code` — `'unverified'` for a normal confident
  extraction; `'needs_review'` for ambiguity.
- `menu_item_source.confidence` — item's existence/name certainty.
- `menu_item_price_source.confidence` — price certainty.

## STEP 6 — Canonical dish and other master-table identification
The JSON does not state a canonical ID unless explicitly supplied; matching
happens on normalized name.

- Normalize: trim, collapse whitespace, case-fold. Don't semantically rewrite
  abbreviations unless matching a confirmed alias.
- Match conservatively: "Chicken 65" ≠ "Chicken 555"; "Veg Manchurian Dry"
  ≠ "Veg Manchurian Gravy." Anything short of an exact normalized match is a
  new canonical row.
- `canonical_dish` has no unique constraint — use `NOT EXISTS`, and always
  insert the paired `canonical_dish_name` row (`name_type_code = 'primary'`,
  `language_code = 'en'`) in the same logical operation.
- **`bar_product`**: same `NOT EXISTS` treatment, matched on `product_name`.
- **`platform_tag`**: read existing row by `tag_code`; never insert a lookup row.
- **`delivery_provider`**: read existing row by uppercase `provider_code`; never
  insert a lookup row.
- **`category_text_alias`**: read/use existing curation mapping where present;
  do not create a new lookup row merely to satisfy extraction.
- `protein_type` and `service_mode` are fixed lookup tables — match, don't create.
- If the restaurant belongs to a known `brand` with an existing
  `brand_menu_template`, check whether items should link via the template rather
  than being created standalone; flag this rather than assuming.

## STEP 7 — SQL patterns
Run once, in order, at the top of the script:

```sql
\connect "KhaustanRestaurantMenu"
BEGIN;
```

Do **not** create a generic sequence for the mandatory deterministic ID
namespaces. The generated SQL must assign those IDs explicitly from the
`{{ESTABLISHMENT_ID}}` namespace.

### Establishment + restaurant
Use the supplied `{{ESTABLISHMENT_ID}}` as the explicit ID for both
`establishment.establishment_id` and `restaurant.restaurant_id`. Do not
replace it with `nextval()` or a database-generated value.

```sql
INSERT INTO establishment (
    establishment_id, name, normalized_name, address_line1, address_line2,
    locality, city, state, country_code, postal_code
)
VALUES (
    {{ESTABLISHMENT_ID}},
    '{{Restaurant Name from JSON}}',
    lower(trim('{{Restaurant Name from JSON}}')),
    '{{Address from JSON}}',
    NULL,
    '{{Locality from JSON if present}}',
    '{{City from JSON if present}}',
    '{{State from JSON if present}}',
    'IN',
    '{{PIN from JSON}}'
);

INSERT INTO restaurant (
    restaurant_id, establishment_id, display_name, normalized_name,
    has_bar, bar_license_type
)
VALUES (
    {{ESTABLISHMENT_ID}},
    {{ESTABLISHMENT_ID}},
    '{{Restaurant Name from JSON}}',
    lower(trim('{{Restaurant Name from JSON}}')),
    {{HAS_BAR_FROM_JSON}},
    '{{BAR_LICENSE_TYPE_FROM_JSON}}'
);

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES ({{ESTABLISHMENT_ID}}, 'ai_menu_extraction', '{{filename.json}}');
```

Create `menu_extraction_batch` with its normal schema-supported standalone ID,
but its `restaurant_id` must be `{{ESTABLISHMENT_ID}}` and its `source_id` must be
`{{ESTABLISHMENT_ID}}`.

### Phones and hours
Use the existing standalone ID approach for `restaurant_phone_id` and
`restaurant_hours_id`; do not confuse those IDs with the mandatory menu-child
namespace.

### Menu board
The first `menu_board_id` is `{{ESTABLISHMENT_ID}}001`. Additional boards, if
present in the JSON and required by the schema, continue sequentially
(`{{ESTABLISHMENT_ID}}002`, `{{ESTABLISHMENT_ID}}003`, …).

### Categories
Create `menu_category` rows for the JSON leaf-level categories in JSON/source
order. Assign `menu_category_id` from the mandatory namespace beginning at
`{{ESTABLISHMENT_ID}}001`, and set `restaurant_id = {{ESTABLISHMENT_ID}}`.
If the JSON explicitly represents parent/child categories, map
`parent_category_id` to the corresponding deterministic category ID; otherwise
leave it NULL. Do not create category rows that are not supported by the JSON.

### One portion-variant dish, start to finish
Use explicit deterministic IDs rather than `nextval()` for
`menu_item_id`, `variant_id`, and `price_id`.

```sql
WITH new_item AS (
  INSERT INTO menu_item (
      menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name,
      raw_category_text, food_classification_code, protein_type_id,
      verification_status_code
  )
  VALUES (
      {{MENU_ITEM_ID_001}},
      {{ESTABLISHMENT_ID}},
      {{CANONICAL_DISH_ID}},
      'Chicken Tikka',
      'chicken tikka',
      'Starters',
      'non_veg',
      {{PROTEIN_TYPE_ID_FROM_EXISTING_LOOKUP}},
      'unverified'
  )
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (
      variant_id, menu_item_id, variant_name, pricing_basis_code, is_default
  )
  SELECT {{VARIANT_ID_001}}, new_item.menu_item_id, 'Half', 'fixed', FALSE
  FROM new_item
  UNION ALL
  SELECT {{VARIANT_ID_002}}, new_item.menu_item_id, 'Full', 'fixed', TRUE
  FROM new_item
)
INSERT INTO menu_item_price (
    price_id, variant_id, price_amount, effective_from,
    source_id, verification_status_code
)
VALUES
    ({{PRICE_ID_001}}, {{VARIANT_ID_001}}, 220.00,
     (clock_timestamp() AT TIME ZONE 'UTC'), {{ESTABLISHMENT_ID}}, 'unverified'),
    ({{PRICE_ID_002}}, {{VARIANT_ID_002}}, 400.00,
     (clock_timestamp() AT TIME ZONE 'UTC'), {{ESTABLISHMENT_ID}}, 'unverified');
```

The generated final SQL must replace every illustrative placeholder above with
its actual deterministic literal ID/value before delivery.

### Menu item source
For every created menu item, insert `menu_item_source` using the exact mapped
`menu_item_id`, `source_id = {{ESTABLISHMENT_ID}}`, and the current extraction
batch ID. There is no `menu_item_source_id` to generate.

### Menu item price source
For every created price, insert `menu_item_price_source` using the exact
mapped `price_id` and `source_id = {{ESTABLISHMENT_ID}}`. There is no separate
standalone ID to generate.

### Menu item availability
When the JSON contains an availability/time-window rule at item level, assign
`availability_id` sequentially beginning at `{{ESTABLISHMENT_ID}}001` and map
`menu_item_id` to the exact corresponding deterministic menu item ID.

### Board-category and board-item mapping
`menu_board_category` has no standalone ID column. Insert the row with:
- `restaurant_id = {{ESTABLISHMENT_ID}}`
- the corresponding `menu_board_id`
- the corresponding `menu_category_id`
- the JSON/source `display_sequence`.

`menu_board_item` must use a deterministic `menu_board_item_id` beginning at
`{{ESTABLISHMENT_ID}}001`, with:
- `restaurant_id = {{ESTABLISHMENT_ID}}`
- the corresponding `menu_board_id`
- the corresponding `menu_item_id`
- the corresponding `menu_category_id` where available
- the JSON/source `display_sequence`.

### Master-table lookup patterns
```sql
-- protein_type: READ ONLY lookup
SELECT protein_type_id
FROM protein_type
WHERE code = 'chicken';

-- service_mode: READ ONLY lookup
SELECT service_mode_id
FROM service_mode
WHERE code = 'takeaway';

-- platform_tag: READ ONLY lookup
SELECT tag_id
FROM platform_tag
WHERE tag_code = 'HALAL';

-- delivery_provider: READ ONLY lookup; code must be uppercase
SELECT delivery_provider_id
FROM delivery_provider
WHERE provider_code = 'ZOMATO';
```

**Never include INSERT statements for these lookup tables in this onboarding
script.** If a required lookup value is missing, surface it in the unmapped
block instead.

### Secondary mechanisms
Populate only where the JSON actually calls for them:
- Add-ons/customization → `addon_group` / `addon_option` /
  `menu_item_addon_group`.
- Thali/combo contents, when separately orderable/priced → `bundle` /
  `bundle_group` / `bundle_component`. Do not invent standalone component menu
  items when the JSON does not establish them.
- Dish photos or media metadata represented by the JSON → `media_asset` /
  `menu_item_media`, only to the extent the JSON supplies a valid URI/reference.
- `change_event_outbox` → do not guess a payload shape not specified by the
  schema; flag as a follow-up integration step.

## STEP 8 — Output format
- `\connect "KhaustanRestaurantMenu"` at the top, then `BEGIN; … COMMIT;`
  around everything — one database, one transaction.
- FK-safe order: deterministic ID assignment → establishment/restaurant →
  source/batch → phones/hours → canonical dishes (+ names) → read-only lookup
  resolution → menu items (+ variants, prices, bar extension) → source links →
  delivery-provider links → availability → board/category/item mappings → any
  secondary mechanisms.
- Start the file with a header comment containing: which restaurant/source this
  is, the supplied establishment namespace, and the `ck_menu_item_price_amount`
  bug note if market-price items are involved.
- Comment each dish block with its JSON source section/path, for example:
  `-- Source: JSON, "menu.sections[2].items"`.
- End with two trailing comment blocks:
  - Every `menu_item` / `menu_item_price` row with
    `verification_status_code = 'needs_review'` or `confidence < 0.8`, with a
    one-line reason.
  - Every restaurant-level note from the JSON that had no schema home.
- **Do not insert any record in lookup tables in the same script.** If lookup
  data needs to be added, that must be a separate script.
- Deliver as a single downloadable `.sql` file, not inline in the chat reply.

---

## Worked example
JSON contains, in order:

> **Starters**
> Chicken Tikka — Half ₹220 / Full ₹400
>
> **Chinese Starters**
> Manchurian (Veg/Chicken) — 180/230
>
> **Bar Menu › Beer**
> Kingfisher Premium (330ml/650ml) — 180/320

Extraction:

| Name | raw_category_text | food_classification_code | protein_type | Variant | Price | Confidence |
|---|---|---|---|---|---:|---:|
| Chicken Tikka | Starters | non_veg | chicken | Half | 220 | 0.95 |
| Chicken Tikka | Starters | non_veg | chicken | Full | 400 | 0.95 |
| Manchurian | Chinese Starters | veg | — | Regular | 180 | 0.9 |
| Manchurian | Chinese Starters | non_veg | chicken | Regular | 230 | 0.9 |
| Kingfisher Premium | Beer | NULL | — | 330ml | 180 | 0.9 |
| Kingfisher Premium | Beer | NULL | — | 650ml | 320 | 0.9 |

In the actual SQL, every deterministic menu-child ID must follow the mandatory
namespace beginning at `{{ESTABLISHMENT_ID}}001`; do not use the illustrative
example IDs as production values.

---

# Data Specific Instructions

## 1. `delivery_provider.provider_code`
Shall always be **UPPERCASE**, example `ZOMATO`. Match only existing lookup rows.

## 2. `platform_tag.tag_code`
Shall always be **UPPERCASE** except for cuisine tags. Cuisine tags use the
format `cuisine_` + cuisine name in lower case.

## 3. Establishment / restaurant / source ID namespace
- `establishment_id` must be exactly **9 digits** and is supplied through
  `{{ESTABLISHMENT_ID}}`.
- `restaurant_id` must equal `establishment_id`.
- `source_id` must equal `establishment_id`.
- The examples `400086001` and `400086001001` are examples only.

## 4. Deterministic 12-digit child ID namespace
All of the following sequences start from `{{ESTABLISHMENT_ID}}001` and then
increment sequentially within their own table/namespace:
- `menu_board.menu_board_id` — first board starts at
  `{{ESTABLISHMENT_ID}}001`.
- `menu_category.menu_category_id`.
- `menu_item.menu_item_id`.
- `menu_item_variant.variant_id`.
- `menu_item_price.price_id`.
- `menu_item_availability.availability_id`.
- `menu_board_item.menu_board_item_id`.

`menu_item_source.menu_item_id` is the corresponding existing
`menu_item_id`; it is **not** a second sequence.

`menu_board_category.restaurant_id` is the corresponding 9-digit
`restaurant_id`/`establishment_id`; it is **not** a second sequence. Map the
`menu_board_id` and `menu_category_id` normally.

## 5. Foreign-key mapping
Map every child FK to the exact deterministic parent ID generated for this
restaurant. Do not mix namespaces from different restaurants, do not reuse
another restaurant's child IDs, and do not use the examples as literals.

## 6. Lookup-table restriction
**DO NOT INSERT ANY RECORD IN LOOKUP TABLES IN THE SAME SCRIPT.**
The attached lookup SQL is reference data only. Read existing lookup rows and
use their IDs. If required lookup data is missing, create a separate lookup
seed script rather than inserting it in the restaurant/menu script.

## 7. Do not use reference of other previous scripts created in chat.
In same chat there may or may not be previously created insert scripts. Do not use them as any reference

## 8. If mandetory data is missing in JSON .
If value for state field for establishment table is not given in JSON use 'Maharashtra' as value
If value for bar_license_type in restaurant is missing in JSON use 'none' as value.

---

# Placeholders

Use these placeholders when the prompt is instantiated for a restaurant. Do not
replace them with the example values unless those values are explicitly supplied
for the target restaurant.

- `{{ESTABLISHMENT_ID}}` — required **9-digit** establishment namespace. It is
  the only restaurant/menu ID root supplied outside the JSON.
- `{{filename.json}}` — exact input JSON filename.
- `{{MENU_BOARD_ID_001}}`, `{{MENU_BOARD_ID_002}}`, … — final values are
  `{{ESTABLISHMENT_ID}}001`, `{{ESTABLISHMENT_ID}}002`, … in JSON/source order.
- `{{MENU_CATEGORY_ID_001}}`, `{{MENU_CATEGORY_ID_002}}`, … — final values are
  `{{ESTABLISHMENT_ID}}001`, `{{ESTABLISHMENT_ID}}002`, … in category order.
- `{{MENU_ITEM_ID_001}}`, `{{MENU_ITEM_ID_002}}`, … — final values are
  `{{ESTABLISHMENT_ID}}001`, `{{ESTABLISHMENT_ID}}002`, … in JSON/source item
  order after required splitting.
- `{{VARIANT_ID_001}}`, `{{VARIANT_ID_002}}`, … — final values are
  `{{ESTABLISHMENT_ID}}001`, `{{ESTABLISHMENT_ID}}002`, … in variant order.
- `{{PRICE_ID_001}}`, `{{PRICE_ID_002}}`, … — final values are
  `{{ESTABLISHMENT_ID}}001`, `{{ESTABLISHMENT_ID}}002`, … in price order.
- `{{AVAILABILITY_ID_001}}`, `{{AVAILABILITY_ID_002}}`, … — final values are
  `{{ESTABLISHMENT_ID}}001`, `{{ESTABLISHMENT_ID}}002`, … in availability order.
- `{{MENU_BOARD_ITEM_ID_001}}`, `{{MENU_BOARD_ITEM_ID_002}}`, … — final values
  are `{{ESTABLISHMENT_ID}}001`, `{{ESTABLISHMENT_ID}}002`, … in board-item
  order.
- `{{PROTEIN_TYPE_ID_FROM_EXISTING_LOOKUP}}` — existing lookup ID only; never
  create a lookup row in this script.
- `{{SERVICE_MODE_ID_FROM_EXISTING_LOOKUP}}` — existing lookup ID only.
- `{{PLATFORM_TAG_ID_FROM_EXISTING_LOOKUP}}` — existing lookup ID only.
- `{{DELIVERY_PROVIDER_ID_FROM_EXISTING_LOOKUP}}` — existing lookup ID only.
- `{{CANONICAL_DISH_ID}}` — schema-supported canonical-dish ID resolved by
  Step 6; not part of the mandatory restaurant/menu child-ID namespace.
- `{{EXTRA_ID_*}}` — only for standalone IDs not covered by the mandatory
  deterministic namespaces, using the existing application-generated approach
  from the schema/prompt.

The examples `400086001` and `400086001001` are format examples only. They must
never be emitted as fixed production IDs unless explicitly supplied as the target
restaurant's namespace.
