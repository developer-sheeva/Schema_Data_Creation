# Khaustan — Menu JSON → PostgreSQL loader · generation prompt

`v1.0 · 14 Oct 2026`

> **How to use.** Open a new Claude chat, attach the files listed in §2, and paste this whole file as your message. Edit only the values in §3.
> The rules and SQL fragments below come from a loader that was run end-to-end on PostgreSQL 16.15 against your schema, lookup seed, `Canonical_Dish.csv` and the Hotel Sunlight JSON; the results are in §14. The optional attachment `khaustan_load_menu_json.sql` is that validated script.

---

## 1. Role

You are a senior PostgreSQL engineer who writes data-migration scripts for live schemas. You check every table, column, constraint and CHECK value against the attached DDL before you use it. You write set-based, transactional, fail-loud SQL. You never invent data. When something is infeasible or underspecified, you say so and apply the documented default instead of improvising.

## 2. Inputs

| Attachment | What it is | How you use it |
|---|---|---|
| `khaustan-KhaustanRestaurantMenu-Create_DB-postgresql.sql` | DDL of the KhaustanRestaurantMenu database (58 tables) | Source of truth for names, PKs, FKs, defaults and CHECK values. |
| `khaustan_lookup_data_seed_KhaustanRestaurantMenu.sql` | Lookup rows: `service_mode`, `protein_type`, `delivery_provider`, `platform_tag`, `price_schedule`, `bar_product_type` | Tells you which tables are lookups. They are read-only for the loader. |
| `Canonical_Dish.csv` | 4,377 rows: `canonical_dish_id`, `canonical_name` | The only allowed source of `canonical_dish_id` values (§9). Learn its naming noise from it. |
| `Hotel_Sunlight_Menu_OCR.json` | OCR output for one restaurant | **Shape example only.** Never copy its values into the script. |
| `khaustan_load_menu_json.sql` *(optional)* | Reference loader v1.0 | If attached, use it as the baseline: diff it against the DDL and CSV, adjust, keep every safety check. If absent, build from this spec. |

If two sources disagree, the order of authority is: DDL, then lookup seed, then this prompt, then the example JSON. Report every disagreement in your flags.

## 3. Run config

```yaml
output_file          : khaustan_load_menu_json.sql
postgres_version     : 16            # validated on 16.15; the script should not need anything newer
input_mode           : psql          # psql | gui   (gui = JSON pasted into a dollar-quoted literal; see Appendix A.1)
fuzzy_enabled        : on            # tier T4, needs pg_trgm
fuzzy_min_sim        : 0.70
fuzzy_min_margin     : 0.05
token_sim_min        : 0.45
default_variant_name : Regular
board_name           : Main Menu
board_type_code      : a_la_carte
market_tokens        : market price|m.p.|m.p|mp|market rate|as per market price
canonical_snapshot   : {rows: 4377, min_id: 10001, max_id: 60465, ids_md5: dfd259ae460e22bf5b83ea02a9fa2356, names_md5: fe69f825c43d80bceabf8df4a0846a1e}
```

If the attached CSV differs from this snapshot, recompute it (Appendix B) and say so in your reply. The script holds every value above in one `ldr_param` temp table so it can be edited in one place.

## 4. Deliverable and reply format

**Produce** one SQL script (`output_file`) that loads exactly one restaurant per run from a JSON document.

**Reply with these three sections only, in this order:**

1. **Summary** — at most 8 lines: what the script does and the exact command to run it.
2. **Flags** — a table (ID, flag, default applied, what you need from me). Include only the §13 items that apply to this run, plus anything new you found.
3. **Verification** — what you executed and the numbers (compare with §14), or `Not executed — static review only` plus the §12 checklist.

Create the script as a file and present it if you can; otherwise give one fenced code block. Do not ask clarifying questions before writing the script: apply the defaults and flag them.

## 5. Hard rules

Breaking any of these makes the script wrong.

| # | Rule |
|---|---|
| H1 | **One transaction.** `BEGIN … COMMIT`, with `\set ON_ERROR_STOP on` as the first statement. Any failure leaves the database exactly as it was. |
| H2 | **INSERT-only.** The only targets are the 14 tables in §8. No UPDATE, DELETE or TRUNCATE on persistent tables. (UPDATE on your own `ldr_*` temp tables is fine.) |
| H3 | **Read-only tables, never written:** every lookup table (`service_mode`, `protein_type`, `delivery_provider`, `platform_tag`, `price_schedule`, `price_schedule_day`, `bar_product_type`, and any other code/reference list in the DDL or seed), plus `canonical_dish`, `canonical_dish_name` and `brand`. If the JSON needs a lookup row that does not exist, do not create it: use NULL for a nullable FK, abort for a NOT NULL one, and report it. |
| H4 | **No `ON CONFLICT`.** A silent skip hides a collision; collisions must fail loudly. |
| H5 | Explicit column lists on every INSERT. No `SELECT *` into a persistent table. No ID, name or price copied from the example JSON into the script. |
| H6 | **DDL allowed:** `CREATE/DROP SEQUENCE ldr_seq_*`, `TEMP` tables (`ON COMMIT DROP`, except the report table), functions in `pg_temp`. **Not allowed:** `CREATE EXTENSION`, permanent tables, permanent functions. |
| H7 | **Plain SQL after the input block.** The only psql-specific lines are `\set ON_ERROR_STOP on`, input variant A (Appendix A.1) and `\pset pager off` before the last SELECT. psql meta-commands break GUI query tools (this project already hit that with `\gexec` and `\connect`). |
| H8 | **Never guess data:** prices, tax, opening hours, veg/non-veg flags, city/state, licence numbers. Unknown means NULL (if nullable), or abort and flag. |
| H9 | Every `RAISE EXCEPTION` says what is wrong and how to fix it. |
| H10 | The last statement is one `SELECT` that returns the report (§11), so GUI tools that show only the last result set show the report. |
| H11 | Deterministic. Every ID-assigning statement orders its input by document order. |

## 6. IDs

### 6.1 PIN

Take the PIN from `restaurant.pincode`, else `restaurant.postal_code`, else the last standalone 6-digit group at the very end of `restaurant.address` (regex `(?:^|[^0-9])([1-9][0-9]{5})[^0-9]*$`). It must match `^[1-8][0-9]{5}$`, otherwise abort. First digit 9 is rejected: PIN 9xxxxx belongs to Army Post Offices, and rejecting it also keeps new IDs clear of the 9001…, 9002… and 9003… ID blocks used by the earlier pilot loads.

### 6.2 `establishment_id` and `restaurant_id`

| JSON has `establishment_id` | JSON has `restaurant_id` | establishment_id | restaurant_id |
|---|---|---|---|
| no | no | allocated (below) | = establishment_id |
| yes | no | the JSON value | = establishment_id |
| no | yes | = restaurant_id, **only if** it is 9 digits starting with the PIN; otherwise abort and ask for an explicit `establishment_id` | the JSON value |
| yes | yes | the JSON value | the JSON value |

A supplied `establishment_id` must be exactly 9 digits and start with the PIN. A supplied `restaurant_id` must be a positive integer of at most 15 digits, so that `restaurant_id × 1000 + 999` fits a BIGINT. If a supplied ID already exists, abort: the loader never updates.

**Allocation (no ID supplied).** Take `pg_advisory_xact_lock` on the PIN, then `max(establishment_id)` within `[PIN×1000, PIN×1000+999]`; the new ID is that maximum + 1, or `PIN×1000+1` if the block is empty. If the maximum is already `PIN×1000+999`, abort (PIN full). Establishment IDs outside the block are ignored. The result is always 9 digits because a PIN is ≥ 100000.

> Example: establishments 400070015 and 400070020 exist and nothing higher on PIN 400070 → the new ID is **400070021**. (Tested.)

Duplicate guard: if an establishment with the same PIN (`postal_code`) and the same `normalized_name` already exists, abort and name it. This is what stops an accidental second run of the same JSON.

### 6.3 Child IDs

Let `rid` be the restaurant_id. Every sequence below starts at `rid×1000+1`.

| Sequence | Column it feeds | Status |
|---|---|---|
| `ldr_seq_menu_category` | `menu_category.menu_category_id` | requested |
| `ldr_seq_menu_item` | `menu_item.menu_item_id`; the same values are the `menu_item_id` stored in `menu_item_source` and `menu_board_item` | requested |
| `ldr_seq_menu_item_variant` | `menu_item_variant.variant_id` | requested |
| `ldr_seq_menu_item_price` | `menu_item_price.price_id` | requested |
| `ldr_seq_menu_item_availability` | `menu_item_availability.availability_id` | requested; created and closed, but unused (the JSON has no availability data) |
| `ldr_seq_menu_board_item` | `menu_board_item.menu_board_item_id` | requested |
| `ldr_seq_menu_board` | `menu_board.menu_board_id` | **added**: `menu_board_item` and `menu_board_category` require a board |
| `ldr_seq_source_record` | `source_record.source_id` | **added**: `menu_item_source.source_id` requires it |
| `ldr_seq_menu_extraction_batch` | `menu_extraction_batch.extraction_batch_id` | **added** |
| `ldr_seq_restaurant_phone` | `restaurant_phone.restaurant_phone_id` | **added**: phones are part of the restaurant block |
| *none* | `menu_board_category` | PK is `(menu_board_id, menu_category_id)`; its `restaurant_id` is the restaurant's own ID, not a sequence value (flag A1) |
| *none* | `menu_item_source` | PK is `(menu_item_id, source_id)` (flag A2) |

### 6.4 Sequence lifecycle

1. **Start of run** (inside the transaction): drop every standalone sequence whose name starts with `ldr_seq_` in `current_schema()`. Skip any sequence owned by a column or identity (`pg_depend` types `a` and `i`). Never touch any other sequence.
2. **After the IDs are resolved:** create each `ldr_seq_<table>` with `START WITH rid×1000+1 MINVALUE rid×1000+1 MAXVALUE rid×1000+999 NO CYCLE`, using dynamic SQL (`CREATE SEQUENCE` cannot take expressions).
3. **Map IDs once.** Assign each ID exactly once, in document order, into a staging temp table (the ID column comes from `nextval` over an ordered subquery), then reuse the staged ID for every foreign key: categories, then items, variants, prices, board items.
4. **End of run** (before COMMIT): drop every `ldr_seq_*` again and put the remaining count, which must be 0, in the report.
5. "Close" is implemented as `DROP SEQUENCE` (flag A5). Because everything is one transaction, a failure also rolls back the sequence creation.

### 6.5 Collision and capacity guards (abort before the first INSERT)

- The block `[rid×1000+1, rid×1000+999]` must be empty in every table of §6.3 that has a sequence.
- At most 999 rows per sequenced table, counted from the JSON before loading (flag A6). `NO CYCLE` plus `MAXVALUE` is the second line of defence.

## 7. JSON contract and parsing

```text
{ "restaurant": { "name", "address", "pincode"*, "city"*, "state"*, "locality", "phone", "email", "website",
                  "latitude", "longitude", "minimum_delivery_price", "timing", "establishment_id", "restaurant_id" },
  "pages": [ { "image_filename", "sections": [ { "category": "STARTERS", "columns": [ COLUMN … ] } ],
               "other_text": [ "…" ] } ] }
COLUMN = { "column_order": 1, "subcategory"?: "PIZZA", "items": [ ITEM … ] }        # leaf
       | { "category": "INDIAN", "columns": [ COLUMN … ] }                           # sub-category wrapper
ITEM   = { "name": "…", "price": "350" }  |  { "name": "…", "prices": [ { "label": "Full", "price": "350" }, … ] }
```

\* The example JSON does not contain `pincode`, `city` or `state`; the PIN sits only inside `address`. Recommend adding these three keys to the OCR output (flag B1). Values may be strings or numbers; blank strings count as missing.

- **One restaurant per file.** Abort if `restaurant` is not an object, `pages` is not an array, `restaurant.name` is missing, or there are no items.
- **Category tree: exactly two levels.** Level 1 is `sections[].category`. Level 2 is the nearest enclosing `columns[].category` wrapper or `columns[].subcategory`. Same-named categories (normalised) under the same parent are merged; the first appearance fixes the display name and order. Deeper nesting → abort.
- **Order.** Document order (page, section, column, item) drives every `display_sequence` and every ID.
- **Item name.** Trim and collapse spaces. Remove the `*New` marker. Remove a trailing `( … )` only if every `/`-separated part of it equals one of the item's own price labels: `Chicken Tandoori Spl. (Full / Half)` becomes `Chicken Tandoori Spl.`, but `Sweet Corn Soup (Sweet)` keeps `(Sweet)`. Never expand abbreviations in stored names (`Chi.`, `Spl.` stay as printed). Items with an empty name are skipped and reported.
- **Variants.** `prices[]` gives one variant per entry (`variant_name` = label as printed, `display_sequence` = position, the first is `is_default`). Otherwise exactly one variant named `default_variant_name`. `pricing_basis_code` is always `'fixed'`: weight and quantity qualifiers in names (`(Per Kg)`, `(5 Pcs)`) are listed in the report, never parsed.
- **Price token → row.** Digits with optional decimals, optional prefix `Rs`, `Rs.`, `INR` or `₹`, optional suffix `/-` → `price_amount`. A token in `market_tokens` (case-insensitive) → `is_market_price = TRUE` with a NULL amount. Anything else (blank, `Sl.Rate`, `ask waiter`) → **no price row**, and it is listed. Currency `INR`; `service_mode_id` and `price_schedule_id` NULL (the price applies to all modes and times); `effective_from` = load timestamp in UTC; `verification_status_code = 'unverified'`.
- **Phone.** Split on `/`, `,`, `;`. Keep digits and a leading `+`, 8–15 characters. The first is `is_primary`.
- **Coordinates.** Numeric and within range, otherwise NULL.
- **Address.** `address_line1` is the address without its last two comma-separated parts (city, then "state PIN"). Accept the state only if it is a real Indian state or UT name; the city is the part before it. JSON keys `city`, `state`, `locality` win when present. If city or state cannot be established, **abort**: never fall back on the schema defaults `'Mumbai'` and `'Maharashtra'`.
- **`other_text`** is never loaded as menu content. Scan it only for the warnings in §11.
- **`normalized_name`** (establishment, restaurant, menu_item are NOT NULL; the DDL defines no rule, flag B3): `lower()`, every run of non-alphanumeric characters → one space, trim. Use the identical rule everywhere.

## 8. Table mapping (insert in this order)

| # | Table | ID / PK | Values |
|---|---|---|---|
| 1 | `establishment` | `establishment_id` (§6.2) | name, normalized_name, address_line1, locality, city, state, `postal_code` = PIN, email_id, website_url, latitude, longitude |
| 2 | `restaurant` | `restaurant_id` | establishment_id, `display_name` = name, normalized_name; all else column defaults; `veg_nonveg_status` NULL |
| 3 | `restaurant_phone` | `ldr_seq_restaurant_phone` | phone_number, is_primary; `is_personal_number` left at its default FALSE (flag B8) |
| 4 | `restaurant_delivery` | PK = restaurant_id | only if `minimum_delivery_price` contains a number: delivery_available = TRUE, self_delivery_available = TRUE, `self_delivery_min_order_amount`, currency_code `'INR'` (assumption, flag B8) |
| 5 | `source_record` | `ldr_seq_source_record` | source_type_code `'ai_menu_extraction'`; external_reference `'menu_json_loader md5:<md5 of the document>'`; source_uri = the file path |
| 6 | `menu_extraction_batch` | `ldr_seq_menu_extraction_batch` | restaurant_id, source_id, started_at = completed_at = load timestamp, status_code `'completed'` |
| 7 | `menu_board` | `ldr_seq_menu_board` | one row: name = `board_name`, board_type_code = `board_type_code` |
| 8 | `menu_category` | `ldr_seq_menu_category` | parent_category_id (level 2 → its level-1 row), name, display_sequence per sibling group; parents before children |
| 9 | `menu_board_category` | PK `(menu_board_id, menu_category_id)`, no sequence | restaurant_id = the restaurant's ID, every category, display_sequence |
| 10 | `menu_item` | `ldr_seq_menu_item` | restaurant_id, menu_category_id (deepest level), `canonical_dish_id` (§9) or NULL, name, normalized_name; `raw_category_text` NULL because the category is already resolved |
| 11 | `menu_item_source` | PK `(menu_item_id, source_id)`, no sequence | one row per item: menu_item_id, source_id, extraction_batch_id |
| 12 | `menu_board_item` | `ldr_seq_menu_board_item` | restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence = item order |
| 13 | `menu_item_variant` | `ldr_seq_menu_item_variant` | menu_item_id, variant_name, `pricing_basis_code` `'fixed'`, display_sequence, is_default |
| 14 | `menu_item_price` | `ldr_seq_menu_item_price` | variant_id, price_amount, currency_code, is_market_price, effective_from, verification_status_code, source_id |

`menu_item_availability`: sequence created and closed as requested, 0 rows. The JSON has no availability data; `(Morning)` and `(Breakfast)` stay in the item names.

**Deliberately not loaded** (say so in the Flags table when relevant): `restaurant_hours` (needs structured days and times, flag B7), `restaurant_tag` and `menu_item_tag` (turning OCR text into tags is a product decision, flag B9), `menu_item_name`, `menu_item_price_source`, `media_asset` and `menu_extraction_image`, add-on and bundle tables, `brand_id`, `change_event_outbox` (flag B10).

## 9. Canonical dish matching

**9.1 Source of truth.** `menu_item.canonical_dish_id` may only hold an ID that is in `Canonical_Dish.csv`. Those rows already exist in `canonical_dish` (the FK needs them) and the loader never inserts into it. The script therefore reads `canonical_dish` and first verifies that it still equals the snapshot in §3: row count, min id, max id and the md5 of the sorted IDs (a names-hash mismatch is only a warning). Mismatch → abort, telling me to re-export the CSV or update the snapshot. **Do not embed the CSV rows in the script**: 4,377 rows are about 120 KB, give no benefit, and are easy to mistranscribe (flag A4). Matching keys are computed on the fly from `canonical_name`; the CSV has no normalised column and no aliases.

**9.2 Keys.** For an item name and for every canonical name: remove `*New`, normalise (§7), then fold abbreviations token by token with the dictionary in Appendix C. Apply it to **both** sides so that `Veg.`/`Vegetable`, `Chi.`/`Chicken` and `Schn.`/`Schezwan` meet. Compute three keys per name: **plain** (normalised, before folding), **full** (folded, parenthetical text kept) and **core** (folded, all parentheticals removed). The dictionary lives inside the script as an inline temp table, not in the database.

**9.3 Tiers.** The first tier that yields a candidate wins; a matched item never moves on to a later tier.

| Tier | Rule | Link |
|---|---|---|
| T1 exact | item plain = canonical plain | automatic |
| T2 expanded | item full = canonical full | automatic |
| T3 core | item full = canonical core, or item core = canonical full, or item core = canonical core (so `(Boneless)`, `(5 Pcs)`, `(Per Kg)` are ignored) | automatic |
| T4 fuzzy | pg_trgm `similarity(item core, canonical core)` ≥ `fuzzy_min_sim`; best beats the runner-up by ≥ `fuzzy_min_margin`, with the runner-up measured across distinct canonical core keys; **and** the guard below | automatic, listed for review |
| — | everything else | `canonical_dish_id` NULL, reported with the best suggestion |

**Combined lines.** A name that, once parentheticals are removed, contains ` / `, or two words of 3+ letters joined by `/` (`Try Cone/Chocolate`), holds several dishes. It is excluded from every tier, gets NULL, and is reported as a combined line.

**T4 guard** (both must hold):
(a) the critical tokens `veg non chicken mutton paneer egg prawn prawns fish seafood beef pork lamb crab mushroom cheese` are identical on both sides;
(b) the two keys contain the same words, or exactly one word on each side differs and `similarity(word_a, word_b) ≥ token_sim_min` (a dropped or added word is never accepted).

Why the guard exists: plain trigram similarity ignores word order and tolerates dropped words. On the example data the best trigram candidate for `Veg. Thali` was `Non Veg. Thali` (0.83), for `Chicken Tikka Biryani` it was `Chicken Biryani` (0.80), and `Tandoori Roti / Tandoori Butter Roti` scored 1.00 against a single dish.

**Ties.** If several canonical rows share the winning key, choose the one whose raw name has no `*`, then the lowest `canonical_dish_id`. Record `tie_broken: n candidates` and list it for review.

**No pg_trgm.** If the extension is missing or `fuzzy_enabled = off`, skip T4, say so in a NOTICE and in the report, and still run T1–T3. Never `CREATE EXTENSION` (flag A7).

## 10. Pre-flight aborts (all before the first INSERT)

1. Not connected to KhaustanRestaurantMenu (`establishment` or `canonical_dish` missing).
2. JSON shape invalid (§7); category nesting deeper than two levels.
3. PIN missing or invalid (§6.1).
4. Supplied IDs malformed (§6.2), or already existing.
5. Same PIN and `normalized_name` already present (duplicate guard).
6. PIN block full (999 establishments).
7. Child-ID block not empty in a sequenced table (§6.5).
8. Capacity above 999 rows for a sequenced table (§6.5).
9. `canonical_dish` differs from the CSV snapshot (§9.1).
10. City or state cannot be established (§7).

## 11. Report (the last result set)

Columns `section, ref, label, detail`, ordered by section.

| Section | One row per | Contents |
|---|---|---|
| `IDS` | fact | json md5 and file, establishment_id and how it was decided, restaurant_id and its child-ID range, PIN, city, state |
| `ROWS_INSERTED` | table | rows inserted per table, including `menu_item_availability` = 0 |
| `CANONICAL_SUMMARY` | tier | counts for T1 to T4, UNMATCHED, and how many unmatched are combined lines |
| `UNMATCHED_CANONICAL` | menu item | **every menu item without a `canonical_dish_id`**: menu_item_id, name, reason (combined line, no candidate, or no safe match with the best suggestion's id, name and similarity) |
| `REVIEW_LINKS` | link | T4 links and tie-broken links |
| `NO_PRICE_ROW` | variant | variants with no price row, and the token found |
| `WARNING` | issue | categories merged across non-adjacent pages; `other_text` lines containing "handwritten"; `timing` text not loaded; phones flagged; default variant name used n times; multi-price labels that are not portions; weight/quantity qualifiers in names; `other_text` lines equal to an existing `platform_tag` (not loaded); items without category; nameless items skipped; duplicate item names |
| `SEQUENCES` | — | `ldr_seq_*` sequences remaining after closing (must be 0) |

The report is built into a temp table inside the transaction and selected after COMMIT. That is why a direct connection is required (flag B15).

## 12. Self-check and test protocol

**Static checklist (always; tick each in your Verification section):**

- [ ] Every table, column and CHECK value used appears in the attached DDL.
- [ ] Only the 14 target tables are written; nothing in H3 is written; no `ON CONFLICT`; no UPDATE/DELETE on persistent tables.
- [ ] The only psql-specific lines are the three allowed in H7.
- [ ] Sequences: `ldr_seq_` prefix, START / MAXVALUE / NO CYCLE, dropped at start and at end, remaining count reported.
- [ ] Every ID-assigning statement is ordered; every FK uses a staged ID.
- [ ] The last statement is the report SELECT.

**Execution (only if you have a code sandbox):**

1. Install PostgreSQL 16, create the database from the DDL, run the seed.
2. `CREATE EXTENSION pg_trgm;` load the CSV into `canonical_dish` (test data only: `normalized_name` = `trim(regexp_replace(lower(canonical_name), '[^[:alnum:]]+', ' ', 'g'))`).
3. Insert two establishments with IDs 400070015 and 400070020 (`postal_code` `'400070'`).
4. Run the script on the example JSON and compare with §14. Run it again: it must abort and change nothing.
5. Remove `restaurant_id` from a copy of the JSON and run it on a fresh database: expect 400070021 for both IDs.
6. Run the pasted-JSON variant through a client with no psql meta-commands (for example psycopg), as one multi-statement string.
7. Hash every lookup table and `canonical_dish` before and after: identical.

## 13. Flags register

**A. Changed from the request because it is infeasible as written**

| ID | Request | What the script does | Why |
|---|---|---|---|
| A1 | Sequence for `menu_board_category (restaurant_id)` | No sequence. Rows are keyed by `(menu_board_id, menu_category_id)`; `restaurant_id` is set to the restaurant's own ID. | The table has no surrogate ID and `restaurant_id` is a tenant column, not a counter. |
| A2 | Sequence for `menu_item_source (menu_item_id)` | No separate sequence. `menu_item_id` carries the `menu_item` sequence values. Adds sequences for `source_record` and `menu_extraction_batch`, which this table needs. | PK is `(menu_item_id, source_id)`. |
| A3 | "SQL accepts a JSON file" | psql `\set` + backtick reads the file client-side; GUI variant pastes the JSON as a literal. | Plain SQL cannot read a client file. `pg_read_file` reads the server's disk and needs privileges managed hosts typically do not grant. |
| A4 | Use `canonical_dish` IDs from the CSV | Reads the `canonical_dish` table, which must equal the CSV snapshot, and refuses to run otherwise. | The IDs must already exist for the FK, and the loader may not insert them. Embedding the rows adds risk and no value. |
| A5 | "Close" sequences | `DROP SEQUENCE` of standalone `ldr_seq_*` sequences only. | PostgreSQL has no close operation for sequences. |
| A6 | `<restaurant_id>001` numbering | At most 999 rows per table per restaurant and 999 establishments per PIN; guarded. | Three-digit suffix. The example uses 393 variants (39% of the limit). |
| A7 | Fuzzy name matching | Automatic only with the T4 guard; needs `pg_trgm`, which the script never installs. | Unguarded similarity produced wrong links (§9.3). |

**B. Needs your data or a decision (default applied in the script)**

| ID | Item | Default |
|---|---|---|
| B1 | PIN not a field in the example JSON | `pincode` key preferred, else parsed from the end of `address`. Add `pincode`, `city`, `state` to the OCR output. |
| B2 | Only `restaurant_id` supplied (the example's case) | `establishment_id := restaurant_id`. Alternative: allocate the establishment separately. |
| B3 | `normalized_name` rule is not defined in the DDL | lower, non-alphanumerics → space, trim. Confirm it equals your app's rule. |
| B4 | 13 blank prices and 13 `Sl.Rate` in the example | No price row, listed. If `Sl.Rate` means market rate, add it to `market_tokens`. |
| B5 | Multi-price lines | Every `prices[]` entry becomes a variant. Labels that are not portions (`VEG./CHICKEN`, two dish names) are flagged. Splitting into separate items with `split_group_key` is not implemented. |
| B6 | Combined `A / B` lines (35 of 375 in the example) | Not linked to a canonical dish; listed for manual splitting. |
| B7 | Opening hours | `timing` is free text and `8:00 am to 12:00 pm` looks like an OCR error; "closed Fridays 1–2 pm" is in `other_text`. `restaurant_hours` not loaded. Needs structured hours. |
| B8 | Phones and delivery | `is_personal_number` stays FALSE (confirm business vs personal lines). `restaurant_delivery` is set from `minimum_delivery_price` with both flags TRUE. |
| B9 | Tags from `other_text` (`HALAL`, `NO BEEF`) | Reported as candidates, not loaded. |
| B10 | `change_event_outbox` | Not written. The DDL says every change should write an outbox row in the same transaction, but payload and expiry rules are not specified. The search index may not see the load until you decide. |
| B11 | Menu board | One board per restaurant (`Main Menu`, `a_la_carte`) exposing all categories. |
| B12 | Same-named sections on different pages | Merged (`CHICKEN DISHES`, pages 3 and 8, becomes one category of 45 items mixing Indian and Chinese dishes). |
| B13 | Canonical CSV quality | 6 name groups collide after normalisation (12 rows); 10 groups (20 rows) once `*New` is stripped; 47 groups (95 rows) after abbreviation folding (`Veg.`/`Vegetable`, `Schn.`/`Schezwan`, `*New` copies). The tie-break picks the row without `*`, then the lowest ID. Consider consolidating the CSV. |
| B14 | Legacy ID blocks | Pilot restaurants use 12-digit blocks starting 9001…, 9002…, 9003…; PINs starting with 9 are rejected and the empty-block check covers the rest. |
| B15 | Connection | Direct connection only: not a transaction-mode pooler (Neon `-pooler` host, PgBouncer). In a GUI, run `ROLLBACK` first if an earlier run failed in the same session. |

## 14. Reference run (for comparison)

PostgreSQL 16.15; database = DDL + seed + CSV + establishments 400070015 and 400070020; all §3 defaults.

| Measure | Value |
|---|---|
| Items / variants / price rows | 375 / 393 (357 default + 36 labelled) / 367 (26 tokens without a number: 13 blank, 13 `Sl.Rate`) |
| Categories | 31 (27 level-1, 4 level-2); `CHICKEN DISHES` merged across pages 3 and 8 |
| IDs | `restaurant_id` 400070012 is in the JSON, so establishment_id = restaurant_id = 400070012; child IDs 400070012001 up to …393 |
| Same JSON without `restaurant_id` | 400070021 for both |
| Other rows | 1 establishment, 1 restaurant, 4 phones, 1 delivery row, 1 source_record, 1 extraction batch, 1 board, 31 board categories, 375 board items, 375 item sources, 0 availability |
| Canonical links | T1 272 · T2 3 · T3 52 · T4 6 · unmatched 42 (35 combined lines + 7 others) → **333 of 375 linked** |
| T4 links (all correct on review) | Makhnwala→Makhanwala, Kolwada→Koliwada, four `Tripple`→`Triple` Fried Rice |
| Without pg_trgm | 327 linked; the run still succeeds |
| Runtime | about 0.8 s |
| Automated checks passed | 23: psql run, GUI-style single-string run (auto and manual commit), every abort path leaves nothing behind (no PIN, PIN starting 9, short restaurant_id, 1,000 items, three category levels, duplicate load), leftover `ldr_seq_*` dropped while an unrelated sequence survives, 10 protected tables byte-identical. A separate GUI session ran a failed load, a rollback and two successful loads back to back. |

---

## Appendix A. Verified SQL fragments

These are extracted verbatim from the validated script. Reuse their logic; keep the names.

### A.1 Close leftovers, then the input block (use exactly one variant)

```sql
-- ---------------------------------------------------------------------
-- STEP 0  close (drop) loader sequences left over from earlier runs
-- ---------------------------------------------------------------------
DO $ldr$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, c.relname
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind = 'S'
       AND c.relname LIKE 'ldr\_seq\_%'
       AND n.nspname = current_schema()
       AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype IN ('a','i'))
  LOOP
    EXECUTE format('DROP SEQUENCE %I.%I', r.nspname, r.relname);
    RAISE NOTICE 'closed leftover sequence %.%', r.nspname, r.relname;
  END LOOP;
END
$ldr$;

-- ---------------------------------------------------------------------
-- STEP 1  input document. Use EXACTLY ONE of the two variants.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE ldr_input (doc jsonb NOT NULL) ON COMMIT DROP;

-- variant A (psql): the file is read client-side, so no server file access is needed
\set menu_json `cat :'json_file'`
INSERT INTO ldr_input VALUES (:'menu_json'::jsonb);
SELECT set_config('ldr.source_file', :'json_file', true);

-- variant B (GUI / any client): delete the three variant-A lines above, then uncomment and paste here
-- INSERT INTO ldr_input VALUES ($ldr_json$
-- { ...paste the whole JSON document here... }
-- $ldr_json$::jsonb);
-- SELECT set_config('ldr.source_file', 'pasted-json', true);
```

### A.2 Resolve the IDs (excerpt from inside the validation `DO` block)

```sql
  -- 5a  PIN
  IF c.pin IS NULL OR c.pin !~ '^[1-8][0-9]{5}$' THEN
    RAISE EXCEPTION 'PIN code missing or invalid (need 6 digits, first digit 1-8). Add restaurant.pincode to the JSON. Found: %', coalesce(c.pin,'<none>'); END IF;
  pinbase := c.pin::bigint * 1000;

  -- 5b  IDs supplied in the JSON must be well-formed
  IF c.est_id_in IS NOT NULL AND (c.est_id_in !~ '^[1-9][0-9]{8}$' OR left(c.est_id_in,6) <> c.pin) THEN
    RAISE EXCEPTION 'establishment_id % must be exactly 9 digits and start with the PIN %', c.est_id_in, c.pin; END IF;
  IF c.rest_id_in IS NOT NULL AND c.rest_id_in !~ '^[1-9][0-9]{0,14}$' THEN
    RAISE EXCEPTION 'restaurant_id % must be a positive integer of at most 15 digits', c.rest_id_in; END IF;

  -- 5c  establishment_id / restaurant_id decision table
  IF c.est_id_in IS NOT NULL THEN
    est := c.est_id_in::bigint;  rule := 'establishment_id from JSON';
  ELSIF c.rest_id_in IS NOT NULL THEN
    IF c.rest_id_in !~ '^[1-9][0-9]{8}$' OR left(c.rest_id_in,6) <> c.pin THEN
      RAISE EXCEPTION 'restaurant_id % cannot also be the establishment_id (needs 9 digits starting with PIN %). Supply establishment_id in the JSON.', c.rest_id_in, c.pin; END IF;
    est := c.rest_id_in::bigint; rule := 'establishment_id = restaurant_id from JSON';
  ELSE
    PERFORM pg_advisory_xact_lock(hashtextextended('khaustan_loader_pin_' || c.pin, 0));
    SELECT max(establishment_id) INTO mx FROM establishment WHERE establishment_id BETWEEN pinbase AND pinbase + 999;
    IF mx IS NULL THEN est := pinbase + 1;
    ELSIF mx >= pinbase + 999 THEN RAISE EXCEPTION 'PIN % is full: establishment_id % already used (max 999 per PIN)', c.pin, mx;
    ELSE est := mx + 1; END IF;
    rule := CASE WHEN mx IS NULL THEN 'allocated: first establishment on PIN' ELSE 'allocated: last on PIN (' || mx || ') + 1' END;
  END IF;
  rid := coalesce(c.rest_id_in::bigint, est);
  IF c.rest_id_in IS NULL THEN rule := rule || '; restaurant_id = establishment_id'; END IF;

  IF EXISTS (SELECT 1 FROM establishment WHERE establishment_id = est) THEN
    RAISE EXCEPTION 'establishment_id % already exists', est; END IF;
  IF EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = rid) THEN
    RAISE EXCEPTION 'restaurant_id % already exists', rid; END IF;
  IF EXISTS (SELECT 1 FROM establishment WHERE postal_code = c.pin AND normalized_name = pg_temp.ldr_norm(c.name)) THEN
    RAISE EXCEPTION 'Possible duplicate: an establishment named "%" already exists on PIN % (id %). Aborting; nothing loaded.',
      c.name, c.pin, (SELECT min(establishment_id) FROM establishment WHERE postal_code = c.pin AND normalized_name = pg_temp.ldr_norm(c.name)); END IF;
```

### A.3 Create the sequences

```sql
-- ---------------------------------------------------------------------
-- STEP 6  create the loader sequences  (START = <restaurant_id>001, MAXVALUE = <restaurant_id>999, NO CYCLE)
-- ---------------------------------------------------------------------
DO $ldr$
DECLARE b bigint; t text;
BEGIN
  SELECT id_base INTO b FROM ldr_ctx;
  FOREACH t IN ARRAY ARRAY['menu_category','menu_item','menu_item_variant','menu_item_price','menu_item_availability',
                           'menu_board_item','menu_board','source_record','menu_extraction_batch','restaurant_phone']
  LOOP
    EXECUTE format('CREATE SEQUENCE %I START WITH %s MINVALUE %s MAXVALUE %s NO CYCLE', 'ldr_seq_' || t, b+1, b+1, b+999);
  END LOOP;
END
$ldr$;
```

### A.4 Flatten pages → sections → nested columns → items

```sql
-- ---------------------------------------------------------------------
-- STEP 4  flatten pages -> sections -> (nested) columns -> items
-- ---------------------------------------------------------------------
CREATE TEMP TABLE ldr_walk ON COMMIT DROP AS
WITH RECURSIVE w(page_no, sec_no, path, top_cat, sub_cat, node, depth, labels) AS (
  SELECT p.n::int, s.n::int, ARRAY[p.n::int, s.n::int], nullif(btrim(s.v->>'category'),''), NULL::text, s.v, 1, 0
    FROM ldr_input i
   CROSS JOIN LATERAL jsonb_array_elements(i.doc->'pages') WITH ORDINALITY AS p(v, n)
   CROSS JOIN LATERAL jsonb_array_elements(coalesce(p.v->'sections','[]'::jsonb)) WITH ORDINALITY AS s(v, n)
  UNION ALL
  SELECT w.page_no, w.sec_no, w.path || c.n::int, w.top_cat,
         coalesce(nullif(btrim(c.v->>'category'),''), nullif(btrim(c.v->>'subcategory'),''), w.sub_cat),
         c.v, w.depth + 1,
         w.labels + CASE WHEN nullif(btrim(c.v->>'category'),'') IS NOT NULL OR nullif(btrim(c.v->>'subcategory'),'') IS NOT NULL THEN 1 ELSE 0 END
    FROM w
   CROSS JOIN LATERAL jsonb_array_elements(coalesce(w.node->'columns','[]'::jsonb)) WITH ORDINALITY AS c(v, n)
)
SELECT * FROM w;

CREATE TEMP TABLE ldr_item_raw ON COMMIT DROP AS
SELECT row_number() OVER (ORDER BY w.page_no, w.path, it.n)::int AS ord,
       w.page_no, w.top_cat, w.sub_cat,
       nullif(btrim(it.v->>'name'),'')  AS raw_name,
       it.v->>'price'                   AS price_raw,
       it.v->'prices'                   AS prices
  FROM ldr_walk w
 CROSS JOIN LATERAL jsonb_array_elements(coalesce(w.node->'items','[]'::jsonb)) WITH ORDINALITY AS it(v, n);

-- cleaned display name, keys, combined-line flag (items with no name are skipped and reported)
CREATE TEMP TABLE ldr_item_stg ON COMMIT DROP AS
SELECT r.*,
       n.name_clean,
       pg_temp.ldr_norm(n.name_clean)                                  AS full_plain,
       pg_temp.ldr_expand(pg_temp.ldr_norm(n.name_clean))              AS full_exp,
       pg_temp.ldr_expand(pg_temp.ldr_norm(pg_temp.ldr_strip_parens(n.name_clean))) AS core_exp,
       (pg_temp.ldr_strip_parens(n.name_clean) ~ '(\s/\s)|(\w{3,}/\w{3,})')        AS combined
  FROM (SELECT * FROM ldr_item_raw WHERE raw_name IS NOT NULL) r
 CROSS JOIN LATERAL (
   SELECT pg_temp.ldr_strip_portion(
            pg_temp.ldr_clean_name(r.raw_name),
            ARRAY(SELECT btrim(p->>'label') FROM jsonb_array_elements(coalesce(r.prices,'[]'::jsonb)) p)
          ) AS name_clean
 ) n;

-- OCR free-text lines (never loaded as menu content; only scanned for review warnings)
CREATE TEMP TABLE ldr_other_text ON COMMIT DROP AS
SELECT pg.n::int AS page_no, t.n::int AS line_no, btrim(t.v #>> '{}') AS txt
  FROM ldr_input i
 CROSS JOIN LATERAL jsonb_array_elements(i.doc->'pages') WITH ORDINALITY AS pg(v, n)
 CROSS JOIN LATERAL jsonb_array_elements(coalesce(pg.v->'other_text','[]'::jsonb)) WITH ORDINALITY AS t(v, n);
```

### A.5 Canonical matching: tiers, guard, fuzzy tier

```sql
-- ---------------------------------------------------------------------
-- STEP 8  canonical_dish matching (reads canonical_dish; NEVER inserts into it)
-- ---------------------------------------------------------------------
CREATE TEMP TABLE ldr_canon ON COMMIT DROP AS
SELECT canonical_dish_id AS id, canonical_name,
       pg_temp.ldr_norm(pg_temp.ldr_clean_name(canonical_name))                                              AS full_plain,
       pg_temp.ldr_expand(pg_temp.ldr_norm(pg_temp.ldr_clean_name(canonical_name)))                          AS full_exp,
       pg_temp.ldr_expand(pg_temp.ldr_norm(pg_temp.ldr_strip_parens(pg_temp.ldr_clean_name(canonical_name)))) AS core_exp,
       (canonical_name LIKE '%*%')                                                                           AS has_star
  FROM canonical_dish;

CREATE TEMP TABLE ldr_match (ord int PRIMARY KEY, canonical_dish_id bigint NOT NULL, tier text NOT NULL, score numeric, note text) ON COMMIT DROP;

INSERT INTO ldr_match
SELECT i.ord, (array_agg(c.id ORDER BY c.has_star, c.id))[1], 'T1_exact', 1.0,
       CASE WHEN count(*) > 1 THEN 'tie_broken: ' || count(*) || ' candidates' END
  FROM ldr_item i JOIN ldr_canon c ON c.full_plain = i.full_plain
 WHERE NOT i.combined GROUP BY i.ord;

INSERT INTO ldr_match
SELECT i.ord, (array_agg(c.id ORDER BY c.has_star, c.id))[1], 'T2_expanded', 1.0,
       CASE WHEN count(*) > 1 THEN 'tie_broken: ' || count(*) || ' candidates' END
  FROM ldr_item i JOIN ldr_canon c ON c.full_exp = i.full_exp
 WHERE NOT i.combined AND i.ord NOT IN (SELECT ord FROM ldr_match) GROUP BY i.ord;

INSERT INTO ldr_match
SELECT i.ord, (array_agg(c.id ORDER BY (c.full_exp = i.core_exp) DESC, c.has_star, c.id))[1], 'T3_core', 0.95,
       CASE WHEN count(*) > 1 THEN 'tie_broken: ' || count(*) || ' candidates' END
  FROM ldr_item i JOIN ldr_canon c ON c.full_exp = i.core_exp OR c.core_exp = i.full_exp OR c.core_exp = i.core_exp
 WHERE NOT i.combined AND i.ord NOT IN (SELECT ord FROM ldr_match) GROUP BY i.ord;

-- helper for the fuzzy tier: critical tokens must agree and at most one differing token (a spelling variant) per side
CREATE OR REPLACE FUNCTION pg_temp.ldr_token_guard(a text, b text, tok_min numeric) RETURNS boolean LANGUAGE plpgsql STABLE AS $f$
DECLARE ta text[] := string_to_array(a, ' ');  tb text[] := string_to_array(b, ' ');
        crit text[] := ARRAY['veg','non','chicken','mutton','paneer','egg','prawn','prawns','fish','seafood','beef','pork','lamb','crab','mushroom','cheese'];
        ao text[]; bo text[];
BEGIN
  IF (SELECT coalesce(array_agg(DISTINCT t ORDER BY t), '{}') FROM unnest(ta) t WHERE t = ANY(crit))
     IS DISTINCT FROM
     (SELECT coalesce(array_agg(DISTINCT t ORDER BY t), '{}') FROM unnest(tb) t WHERE t = ANY(crit)) THEN RETURN false; END IF;
  ao := ARRAY(SELECT unnest(ta) EXCEPT SELECT unnest(tb));
  bo := ARRAY(SELECT unnest(tb) EXCEPT SELECT unnest(ta));
  IF cardinality(ao) = 0 AND cardinality(bo) = 0 THEN RETURN true; END IF;
  IF cardinality(ao) = 1 AND cardinality(bo) = 1 THEN RETURN similarity(ao[1], bo[1]) >= tok_min; END IF;
  RETURN false;
END $f$;

CREATE TEMP TABLE ldr_canon_key ON COMMIT DROP AS
SELECT DISTINCT ON (core_exp) core_exp, id AS rep_id, canonical_name AS rep_name
  FROM ldr_canon ORDER BY core_exp, has_star, id;

DO $ldr$
BEGIN
  IF (SELECT has_trgm FROM ldr_ctx) AND (SELECT v FROM ldr_param WHERE k = 'fuzzy_enabled') = 'on' THEN
    EXECUTE 'SET LOCAL pg_trgm.similarity_threshold = 0.3';
    EXECUTE 'CREATE INDEX ldr_canon_key_trgm ON ldr_canon_key USING gin (core_exp gin_trgm_ops)';
    EXECUTE $q$
      CREATE TEMP TABLE ldr_cand ON COMMIT DROP AS
      SELECT r.*, row_number() OVER (PARTITION BY r.ord ORDER BY r.sim DESC, r.rep_id) AS rn
        FROM (SELECT u.ord, u.core_exp AS icore, k.core_exp AS ccore, k.rep_id, k.rep_name,
                     similarity(u.core_exp, k.core_exp) AS sim
                FROM ldr_item u JOIN ldr_canon_key k ON k.core_exp % u.core_exp
               WHERE NOT u.combined AND u.ord NOT IN (SELECT ord FROM ldr_match)) r $q$;
    EXECUTE $q$
      INSERT INTO ldr_match
      SELECT b.ord, b.rep_id, 'T4_fuzzy', round(b.sim::numeric, 3),
             'fuzzy sim=' || round(b.sim::numeric,3) || ' margin=' || round((b.sim - coalesce(s.sim,0))::numeric,3) || ' -> ' || b.rep_name
        FROM ldr_cand b LEFT JOIN ldr_cand s ON s.ord = b.ord AND s.rn = 2
       WHERE b.rn = 1
         AND b.sim >= (SELECT v::numeric FROM ldr_param WHERE k = 'fuzzy_min_sim')
         AND b.sim - coalesce(s.sim,0) >= (SELECT v::numeric FROM ldr_param WHERE k = 'fuzzy_min_margin')
         AND pg_temp.ldr_token_guard(b.icore, b.ccore, (SELECT v::numeric FROM ldr_param WHERE k = 'token_sim_min')) $q$;
  ELSE
    RAISE NOTICE 'fuzzy tier skipped (pg_trgm missing or fuzzy_enabled=off); exact / abbreviation / qualifier tiers still ran';
    EXECUTE 'CREATE TEMP TABLE ldr_cand (ord int, icore text, ccore text, rep_id bigint, rep_name text, sim real, rn bigint) ON COMMIT DROP';
  END IF;
END
$ldr$;
```

## Appendix B. Recompute the canonical snapshot

From the CSV:

```python
import pandas as pd, hashlib
df = pd.read_csv('Canonical_Dish.csv', dtype=str, keep_default_na=False)
df['id'] = df.canonical_dish_id.astype(int); df = df.sort_values('id')
print(len(df), df.id.min(), df.id.max())
print(hashlib.md5("\n".join(map(str, df.id)).encode()).hexdigest())                                    # ids_md5
print(hashlib.md5("\n".join(f"{i}:{n}" for i, n in zip(df.id, df.canonical_name)).encode()).hexdigest())  # names_md5
```

From the database (gives the same values when the table equals the CSV):

```sql
SELECT count(*), min(canonical_dish_id), max(canonical_dish_id),
       md5(string_agg(canonical_dish_id::text, E'\n' ORDER BY canonical_dish_id)) AS ids_md5,
       md5(string_agg(canonical_dish_id::text || ':' || canonical_name, E'\n' ORDER BY canonical_dish_id)) AS names_md5
FROM canonical_dish;
```

## Appendix C. Abbreviation dictionary (starter)

Applied to both item names and canonical names after normalisation. Add a token only when it is unambiguous; extend it after reading `UNMATCHED_CANONICAL`.

| Token | Folds to |
|---|---|
| `chi`, `chic` | `chicken` |
| `mut` | `mutton` |
| `spl`, `sp` | `special` |
| `schn`, `schezn` | `schezwan` |
| `vegetable`, `vegetables` | `veg` |
| `pcs`, `piece`, `pieces` | `pc` |
