# Khaustan — Claude Project Context & Lookup Reference

*Covers: khaustan-KhaustanRestaurantMenu-Create_DB-postgresql.sql,
khaustan_lookup_data_seed_KhaustanRestaurantMenu.sql,
Khaustan_Execute_All_PostgreSQL.sql (as uploaded this turn).*

## Steps — making this durable across conversations

Memory on my side can hold curated facts (and now does — the lookup IDs below
are saved), but it can't hold full source files, and it goes stale the moment
the schema changes without me being told. The reliable fix is the **Project
knowledge** feature on claude.ai:

1. Open the Khaustan project → project settings → add files.
2. Upload the actual source files, not summaries of them: the DDL
   (`khaustan-KhaustanRestaurantMenu-Create_DB-postgresql.sql`), the lookup
   seed (`khaustan_lookup_data_seed_KhaustanRestaurantMenu.sql`), the driver
   (`Khaustan_Execute_All_PostgreSQL.sql`), and the Identity/Behaviour/Reviews
   DDL once you have it in hand. Every conversation started inside the project
   then has them available without re-uploading.
3. When the schema changes — a column added, a constraint fixed, a new
   lookup table — replace the file in Project knowledge with the new version.
   That's the one update that keeps every future conversation current; this
   document and my memory are a snapshot of today, not a live mirror.
4. Keep this file (or an updated version of it) in Project knowledge too —
   it's the fast-scan index; the DDL is the source of truth when the two
   disagree.

## What changed since the schema version I'd been working from

This upload is a newer DDL than the one I read earlier in this conversation.
Diffing the two directly (not from memory) found:

- **`bar_product_type` is a new lookup table.** `bar_product.product_type_id`
  is now an `INT` FK to it, replacing the old `product_type_code` text
  column with a `CHECK` list. Any bar-menu SQL written against the old
  column name needs updating.
- **The `menu_item_price` CHECK constraint is fixed.** It now compares
  `is_market_price` to `TRUE`/`FALSE`; earlier it compared to integer `1`/`0`,
  which Postgres rejects outright (`operator does not exist: boolean =
  integer`) — I'd flagged this as a bug earlier this conversation. It's
  fixed now, so a market-price row (`is_market_price = TRUE`, `price_amount
  = NULL`) can actually be inserted going forward.
- **`bar_menu_item.bar_item_type_code`** lost its fixed value list (`spirit`,
  `cocktail`, etc.) — now accepts any `VARCHAR(40)`.
- **`brand` and `establishment`** both gained an `email_id` column.
- **`establishment.latitude`/`longitude`** precision increased from
  `DECIMAL(9,6)` to `DECIMAL(17,14)`. Source JSONs in this project typically
  give 14+ decimal places — those were being silently truncated to 6 before;
  they'll store in full now.

## Lookup reference — real IDs, not inferred ones

Match on these exactly. The single most important rule: **most business-key
codes are UPPERCASE** (`protein_type.code`, `platform_tag.tag_code` except
the `cuisine_*` ones, `delivery_provider.provider_code`). `service_mode.code`
and `bar_product_type.bar_product_code` are lowercase/mixed.

**protein_type** (gaps at 900004–900006, 920001–920006 are real — not filled)
| id | code |
|---|---|
| 900001 | CHICKEN |
| 900002 | MUTTON |
| 900003 | SEAFOOD |
| 920007 | BEEF |
| 920008 | PORK |
| 920009 | EGG |
| 920010 | OTHER |

**delivery_provider**
| id | code | active |
|---|---|---|
| 1 | ZOMATO | yes |
| 2 | SWIGGY | yes |
| 3 | DUNZO | **no** — insolvent, kept for historical rows only |
| 4 | SELF | yes |

**service_mode**: 1 dine_in, 2 drive_through, 3 takeaway, 4 delivery,
5 bulk_catering, 6 room_service.

**platform_tag** (selected — restaurant-level tags all use
`tag_scope='restaurant_filter'`, not `'restaurant'`):
81 HALAL · 82 NO_BEEF · 83 JAIN_AVAILABLE · 88 PURE_VEG · 101 SEAFOOD ·
102 OVER_NIGHT · 51–57 menu_item-scope (NUT_FREE, GLUTEN_FREE,
LACTOSE_FRIENDLY, SPICY, BESTSELLER, CHEFS_SPECIAL, GREEN_GRAVY) ·
201–237 `cuisine_*` (lowercase, e.g. `cuisine_malvani`).

**price_schedule**: 1 Breakfast · 2 Lunch · 3 Happy Hour · 4 Dinner ·
5 Late Night (23:00→02:00, spans midnight) · 6 Weekend Brunch. No unique
constraint on `name` yet, per the seed file's own note.

**bar_product_type** (selected): 111 BEER · 121 VODKA · 131 RUM · 141 GIN ·
151 BRANDY · 301 WINE — full list in the seed file.

## Action needed on scripts already generated this conversation

Before this upload, I had no access to the real lookup data and resolved
`protein_type`/`platform_tag` by joining on a *lowercase* code I guessed
(`'chicken'`, `'halal'`) rather than the real uppercase one. Checking what I
actually delivered:

- **Arabian Dastarkhwan, Hotel Nasheman, New Lucky, Hotel Malvan Swad** —
  every non-veg `menu_item` row's `protein_type_id` JOIN would have matched
  zero rows (wrong case), so it's `NULL` where it should be a real ID.
- **Arabian Dastarkhwan, Hotel Nasheman, New Lucky** — the HALAL
  `restaurant_tag` insert also matched zero rows for the same reason, even
  though `HALAL` genuinely exists at id 81.
- **Vihar's** `delivery_provider` lookup was fine — the source JSON's
  "ZOMATO, SWIGGY" was already uppercase, so it passed through correctly
  by coincidence.
- Nothing delivered touched `bar_product`, so the `product_type_id` schema
  change doesn't affect any already-generated script.

If those four scripts haven't been run against a live database yet, I can
regenerate them with the corrected case. If they have already been run, the
fix is a separate repair pass (re-deriving the intended protein per item and
updating `protein_type_id`/`restaurant_tag` after the fact) rather than a
re-run — let me know which situation it is and I'll build whichever one
applies.
