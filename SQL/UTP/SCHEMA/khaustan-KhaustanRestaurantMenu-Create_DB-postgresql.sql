/* ============================================================================
   KHAUSTAN.COM — KhaustanRestaurantMenu DATABASE DEPLOYMENT SCRIPT (POSTGRESQL)
   Run top-to-bottom with psql against a PostgreSQL server. Nothing needs to
   exist beforehand; each CREATE DATABASE is conditionally executed and each
   database is then selected with a psql \connect command so the four-service
   architecture remains four independent databases.

   Need FOUR separate databases, not four sets of tables in one database.
   Each one is a genuinely independent microservice's data store, matching
   the architecture established across this project: no foreign key in this
   file ever crosses a database boundary. Where one service needs to refer
   to a row that lives in another (a review's restaurant_id, a search log's
   user_id), it is stored as a plain BIGINT with a comment, deliberately not
   an enforced constraint, because a FOREIGN KEY cannot span two databases.

     1. KhaustanRestaurantMenu   -- establishments, menus, pricing, bar, delivery capability, OCR provenance (57 tables)
     2. KhaustanIdentity         -- registered users + guest sessions (4 tables)
     3. KhaustanSearchBehavior   -- search queries, impressions, clicks (3 tables)
     4. KhaustanReviews          -- reviews, dish tags, replies, moderation (7 tables)

   POSTGRESQL-SPECIFIC CHOICES MADE IN THIS VERSION:
     - TIMESTAMP(3) WITHOUT TIME ZONE is used for the former SQL Server
       DATETIME2(3) columns because all timestamps are intentionally stored as
       UTC without a timezone component, matching the source model's intent.
     - (clock_timestamp() AT TIME ZONE 'UTC') is used for the former
       SYSUTCDATETIME() defaults so each inserted row receives the current UTC
       wall-clock time rather than the transaction start timestamp.
     - BOOLEAN is used for SQL Server BIT columns, with FALSE/TRUE replacing
       0/1 defaults.
     - VARCHAR(n) is used for NVARCHAR(n), and TEXT for NVARCHAR(MAX).
       PostgreSQL strings are Unicode, so a separate NVARCHAR type is not
       required.
     - BIGINT primary keys remain application-generated; no identity/sequence
       was introduced because the source script explicitly relies on
       application-assigned keys.
     - PostgreSQL does not support SQL Server's USE or GO statements. The
       database transitions are implemented with psql \connect commands, and
       conditional database creation uses a psql \gexec pattern because
       CREATE DATABASE cannot run inside a transaction block and has no
       portable IF NOT EXISTS form.
     - Cross-database references remain ordinary BIGINT columns exactly as in
       the source architecture; PostgreSQL cannot enforce foreign keys across
       separate databases.
     - The resulting script is therefore intended to be executed by psql (or
       an equivalent client that supports \connect and \gexec).

   MIGRATION VALIDATION NOTE:
   This port is based on the supplied, tested SQL Server source script.
   The converted file was statically reviewed for remaining SQL Server-only
   batch/control-flow syntax, data-type compatibility, timestamp defaults,
   foreign-key ordering, and four-database execution flow. Because execution
   against the user's PostgreSQL server is not available in this environment,
   run the script once in a disposable PostgreSQL environment as the final
   operational validation step.

   SCRIPT IS ONLY FOR ONE DATABASE KhaustanRestaurantMenu
   ============================================================================ */

/* ============================================================================
   DATABASE — KhaustanRestaurantMenu
   Establishments, menus, pricing, bar, delivery capability, OCR provenance. 57 tables.
   ============================================================================ */

SELECT format('CREATE DATABASE %I', :'DBname')
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_database
    WHERE datname = :'DBname'
)\gexec

\connect :"DBname"

CREATE TABLE brand (
    brand_id        BIGINT NOT NULL PRIMARY KEY,
    name             VARCHAR(200) NOT NULL,
    normalized_name   VARCHAR(200) NOT NULL,
    legal_name         VARCHAR(250),
    description          VARCHAR(1000),
    website_url           VARCHAR(500),
    email_id              VARCHAR(200),
    youtube_channel        VARCHAR(500),
    status_code             VARCHAR(30) NOT NULL DEFAULT 'active' CHECK (status_code IN ('active','inactive')),
    created_at                TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                  TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC')
);

-- The physical premises/kitchen. Not customer-facing on its own.
CREATE TABLE establishment (
    establishment_id   BIGINT NOT NULL PRIMARY KEY,
    name                 VARCHAR(250) NOT NULL,
    normalized_name        VARCHAR(250) NOT NULL,
    address_line1             VARCHAR(300),
    address_line2                VARCHAR(300),
    locality                       VARCHAR(150),
    city                              VARCHAR(100) NOT NULL DEFAULT 'Mumbai',
    state                               VARCHAR(100) NOT NULL DEFAULT 'Maharashtra',
    country_code                          CHAR(2) NOT NULL DEFAULT 'IN',
    postal_code                             VARCHAR(15),
    email_id                                 VARCHAR(200),
    website_url                              VARCHAR(500),
    instagram_handle                         VARCHAR(150),
    facebook_handle                         VARCHAR(150),
    latitude                                  DECIMAL(17,14),
    longitude                                   DECIMAL(17,14),
    status_code                                   VARCHAR(30) NOT NULL DEFAULT 'active' CHECK (status_code IN ('active','inactive')),
    created_at                                      TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                                        TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC')
);

-- The customer-facing, searchable listing. One establishment can have
-- several (a hotel's restaurant + rooftop bar + coffee lounge; a cloud
-- kitchen's three delivery-only brands).
CREATE TABLE restaurant (
    restaurant_id       BIGINT NOT NULL PRIMARY KEY,
    establishment_id       BIGINT NOT NULL,
    brand_id                  BIGINT,
    display_name                 VARCHAR(250) NOT NULL,
    normalized_name                 VARCHAR(250) NOT NULL,
    description                        VARCHAR(2000),

    -- Denormalized roll-up flags — restored from the original khaustan
    -- schema. Among the highest-frequency filter predicates at
    -- 1,000,000-restaurant scale, so they live here as plain indexed
    -- columns rather than being computed via a join/aggregate over
    -- menu_item on every search hit. A periodic reconciliation job should
    -- compare these against the actual menu_item population and flag
    -- mismatches, so "denormalized" doesn't silently drift into "wrong".
    veg_nonveg_status            VARCHAR(20) CHECK (veg_nonveg_status IN ('pure_veg','non_veg','veg_and_nonveg')),
    has_bar                         BOOLEAN NOT NULL DEFAULT FALSE,
    bar_license_type                   VARCHAR(30) NOT NULL DEFAULT 'none' CHECK (bar_license_type IN ('none','beer_wine_only','full_bar')),
    cost_for_two_amount                   DECIMAL(12,2),
    cost_for_two_currency                    CHAR(3) DEFAULT 'INR',

    listing_tier_code                          VARCHAR(30),  -- cache written by the billing/monetization service; not owned here
    status_code                                   VARCHAR(30) NOT NULL DEFAULT 'active'
                                                   CHECK (status_code IN ('active','temporarily_closed','permanently_closed','coming_soon')),
    is_24_hours                                      BOOLEAN NOT NULL DEFAULT FALSE,

    -- Cache written by the review service — not review storage itself,
    -- just a snapshot for fast display without a cross-service call.
    rating_average                                      DECIMAL(3,2) CHECK (rating_average IS NULL OR (rating_average BETWEEN 0 AND 5)),
    rating_count                                            INT CHECK (rating_count IS NULL OR rating_count >= 0),

    last_verified_at                                            TIMESTAMP(3) WITHOUT TIME ZONE,
    verification_status_code                                       VARCHAR(30) NOT NULL DEFAULT 'unverified'
                                                                    CHECK (verification_status_code IN ('unverified','needs_review','verified')),

    created_at                                                       TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                                                         TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),

    CONSTRAINT fk_restaurant_establishment FOREIGN KEY (establishment_id) REFERENCES establishment(establishment_id),
    CONSTRAINT fk_restaurant_brand FOREIGN KEY (brand_id) REFERENCES brand(brand_id),
    CONSTRAINT uq_restaurant_tenant UNIQUE (restaurant_id, establishment_id)
);

-- Restored from the original khaustan schema — a literal field in the OCR
-- pipeline's own output ("restaurant name, phone numbers, address") that
-- the uploaded schema has no table for at all.
CREATE TABLE restaurant_phone (
    restaurant_phone_id   BIGINT NOT NULL PRIMARY KEY,
    restaurant_id            BIGINT NOT NULL,
    phone_number                 VARCHAR(20) NOT NULL,
    is_primary                      BOOLEAN NOT NULL DEFAULT FALSE,
    is_personal_number                 BOOLEAN NOT NULL DEFAULT FALSE,  -- DPDP flag: small-vendor personal line vs. business line
    CONSTRAINT fk_restaurant_phone_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id)
);

-- Dedup anchor against Zomato/Swiggy/partner IDs when bootstrapping from
-- multiple data sources.
CREATE TABLE restaurant_external_identity (
    identity_id             BIGINT NOT NULL PRIMARY KEY,
    restaurant_id              BIGINT NOT NULL,
    source_system_code            VARCHAR(50) NOT NULL,
    external_restaurant_id           VARCHAR(200) NOT NULL,
    created_at                         TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_restaurant_external_identity_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT uq_restaurant_external_identity UNIQUE (source_system_code, external_restaurant_id)
);


-- ----------------------------------------------------------------------------
-- SECTION 2: Extensible tags, service modes, hours
-- platform_tag + restaurant_tag are kept from the uploaded schema — one
-- unified extensible mechanism beats the original khaustan schema's two
-- parallel tables (establishment_category + amenity) for the same need.
-- menu_item_tag is NEW: the uploaded schema documented a 'menu_item' tag
-- scope as intended but never built the junction table to use it — this
-- finishes that wiring and is where long-tail dietary/allergen tags live
-- (see Section 7 for why they don't live as fixed boolean columns).
-- ----------------------------------------------------------------------------

CREATE TABLE platform_tag (
    tag_id         BIGINT NOT NULL PRIMARY KEY,
    tag_code         VARCHAR(80) NOT NULL UNIQUE,
    name               VARCHAR(150) NOT NULL,
    tag_scope            VARCHAR(30) NOT NULL CHECK (tag_scope IN ('restaurant_format','restaurant_filter','menu_item')),
    value_type              VARCHAR(20) NOT NULL CHECK (value_type IN ('boolean','text','number')),
    is_multivalue              BOOLEAN NOT NULL DEFAULT FALSE,
    is_active                    BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE restaurant_tag (
    restaurant_tag_id   BIGINT NOT NULL PRIMARY KEY,
    restaurant_id           BIGINT NOT NULL,
    tag_id                     BIGINT NOT NULL,
    value_text                    VARCHAR(250),
    value_number                     DECIMAL(18,4),
    value_boolean                       BOOLEAN,
    created_at                             TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                               TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_restaurant_tag_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT fk_restaurant_tag_tag FOREIGN KEY (tag_id) REFERENCES platform_tag(tag_id),
    CONSTRAINT uq_restaurant_tag_value UNIQUE NULLS NOT DISTINCT (restaurant_id, tag_id, value_text)
);

-- Long-tail dietary/allergen/other item tags — halal, gluten-free,
-- onion-garlic-free, nut-free, kosher, and whatever comes up later, as
-- INSERT-only additions to platform_tag, never a schema change. Compare
-- with menu_item's own is_jain/is_vegan/is_eggless columns (Section 7),
-- which stay first-class because they're the highest-frequency search
-- predicates and worth a direct index. The FK to menu_item is added at the
-- end of Section 7, once that table exists.
CREATE TABLE menu_item_tag (
    menu_item_id   BIGINT NOT NULL,
    tag_id            BIGINT NOT NULL,
    value_text           VARCHAR(250),
    PRIMARY KEY (menu_item_id, tag_id),
    CONSTRAINT fk_menu_item_tag_tag FOREIGN KEY (tag_id) REFERENCES platform_tag(tag_id)
);

CREATE TABLE service_mode (
    service_mode_id   BIGINT NOT NULL PRIMARY KEY,
    code                 VARCHAR(40) NOT NULL UNIQUE
                          CHECK (code IN ('dine_in','takeaway','delivery','drive_through','room_service','bulk_catering')),
    name                     VARCHAR(100) NOT NULL,
    is_active                  BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE restaurant_service_mode (
    restaurant_id     BIGINT NOT NULL,
    service_mode_id      BIGINT NOT NULL,
    is_active                BOOLEAN NOT NULL DEFAULT TRUE,
    notes                       VARCHAR(500),
    PRIMARY KEY (restaurant_id, service_mode_id),
    CONSTRAINT fk_restaurant_service_mode_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT fk_restaurant_service_mode_mode FOREIGN KEY (service_mode_id) REFERENCES service_mode(service_mode_id)
);

CREATE TABLE restaurant_hours (
    restaurant_hours_id   BIGINT NOT NULL PRIMARY KEY,
    restaurant_id             BIGINT NOT NULL,
    day_of_week                  SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),   -- 1 = Monday
    slot_sequence                    SMALLINT NOT NULL,
    opens_at                            TIME NOT NULL,
    closes_at                              TIME NOT NULL,
    CONSTRAINT fk_restaurant_hours_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT uq_restaurant_hours_slot UNIQUE (restaurant_id, day_of_week, slot_sequence)
);

CREATE TABLE restaurant_holiday_hours (
    holiday_hours_id   BIGINT NOT NULL PRIMARY KEY,
    restaurant_id          BIGINT NOT NULL,
    holiday_date               DATE NOT NULL,
    is_closed                     BOOLEAN NOT NULL DEFAULT TRUE,
    opens_at                         TIME,
    closes_at                           TIME,
    notes                                  VARCHAR(300),
    CONSTRAINT fk_restaurant_holiday_hours_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT uq_restaurant_holiday_hours UNIQUE (restaurant_id, holiday_date)
);


-- ----------------------------------------------------------------------------
-- SECTION 3: Protein type
-- RESTORED — present in the original khaustan schema, entirely absent from
-- the uploaded one, despite being in the very first message of the whole
-- design conversation ("under non-veg some have chicken, mutton, seafood").
-- This is not the same thing as veg/non-veg/egg classification (Section 7)
-- — without it, "show me every seafood dish" has no structured field to
-- query and falls back to text search on the item name.
-- ----------------------------------------------------------------------------

CREATE TABLE protein_type (
    protein_type_id   BIGINT NOT NULL PRIMARY KEY,
    code                 VARCHAR(30) NOT NULL UNIQUE,   -- chicken, mutton, seafood, egg, pork, beef, other
    label                   VARCHAR(50) NOT NULL
);


-- ----------------------------------------------------------------------------
-- SECTION 4: Canonical dish (cross-restaurant identity)
-- ----------------------------------------------------------------------------

CREATE TABLE canonical_dish (
    canonical_dish_id       BIGINT NOT NULL PRIMARY KEY,
    canonical_name              VARCHAR(250) NOT NULL,
    normalized_name                VARCHAR(250) NOT NULL,
    description                       VARCHAR(2000),
    food_classification_code            VARCHAR(20) CHECK (food_classification_code IN ('veg','egg','non_veg')),
    default_protein_type_id                BIGINT REFERENCES protein_type(protein_type_id),

    -- Nullable, unlike the uploaded schema's NOT NULL booleans — NULL means
    -- "not established," not "confirmed false." See Section 7.
    is_jain                                   BOOLEAN,
    is_vegan                                    BOOLEAN,
    is_eggless                                    BOOLEAN,

    created_at                                       TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                                          TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC')
);

CREATE TABLE canonical_dish_name (
    canonical_dish_name_id   BIGINT NOT NULL PRIMARY KEY,
    canonical_dish_id            BIGINT NOT NULL,
    language_code                    VARCHAR(20) NOT NULL,   -- 'en', 'hi', 'mr', ...
    name                                 VARCHAR(250) NOT NULL,
    normalized_name                         VARCHAR(250) NOT NULL,
    name_type_code                             VARCHAR(30) NOT NULL CHECK (name_type_code IN ('primary','alias','translation')),
    CONSTRAINT fk_canonical_dish_name_dish FOREIGN KEY (canonical_dish_id) REFERENCES canonical_dish(canonical_dish_id),
    CONSTRAINT uq_canonical_dish_name UNIQUE (canonical_dish_id, language_code, name_type_code, name)
);


-- ----------------------------------------------------------------------------
-- SECTION 5: Brand master menu (chain inheritance)
-- ----------------------------------------------------------------------------

CREATE TABLE brand_menu_template (
    template_id    BIGINT NOT NULL PRIMARY KEY,
    brand_id          BIGINT NOT NULL,
    name                 VARCHAR(200) NOT NULL,
    version_no              INT NOT NULL,
    is_active                  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                    TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                      TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_brand_menu_template_brand FOREIGN KEY (brand_id) REFERENCES brand(brand_id),
    CONSTRAINT uq_brand_menu_template_version UNIQUE (brand_id, version_no)
);

CREATE TABLE brand_menu_template_board (
    template_board_id   BIGINT NOT NULL PRIMARY KEY,
    template_id             BIGINT NOT NULL,
    name                       VARCHAR(200) NOT NULL,
    board_type_code               VARCHAR(40) NOT NULL,  -- see menu_board.board_type_code for the shared value list
    description                      VARCHAR(1000),
    display_sequence                    INT NOT NULL DEFAULT 0,
    is_active                              BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_brand_menu_template_board_template FOREIGN KEY (template_id) REFERENCES brand_menu_template(template_id)
);

CREATE TABLE brand_menu_template_item (
    template_item_id    BIGINT NOT NULL PRIMARY KEY,
    template_id             BIGINT NOT NULL,
    canonical_dish_id          BIGINT REFERENCES canonical_dish(canonical_dish_id),
    name                          VARCHAR(250) NOT NULL,
    description                      VARCHAR(2000),
    food_classification_code            VARCHAR(20) CHECK (food_classification_code IN ('veg','egg','non_veg')),
    protein_type_id                        BIGINT REFERENCES protein_type(protein_type_id),
    is_jain                                   BOOLEAN,
    is_vegan                                    BOOLEAN,
    is_eggless                                    BOOLEAN,
    status_code                                     VARCHAR(30) NOT NULL DEFAULT 'active' CHECK (status_code IN ('active','retired')),
    created_at                                         TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                                            TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_brand_menu_template_item_template FOREIGN KEY (template_id) REFERENCES brand_menu_template(template_id)
);


-- ----------------------------------------------------------------------------
-- SECTION 6: Menu boards and the restaurant-defined category tree
-- menu_board is the reusable menu context (à la carte / buffet / thali /
-- bar / breakfast / kids / catering / ...). menu_category is a
-- self-referencing tree PER RESTAURANT with a tenant-safety fix neither
-- source schema had: a composite foreign key (restaurant_id,
-- parent_category_id) -> menu_category(restaurant_id, menu_category_id),
-- so a category can never be linked as a child of another restaurant's
-- category. The uploaded schema's own docs flagged this as something "best
-- enforced in the service transaction because a simple FK cannot express
-- it" — a composite FK against a (restaurant_id, id) unique pair actually
-- can express it declaratively, no trigger needed. Proven in Section 19.
-- ----------------------------------------------------------------------------

CREATE TABLE menu_board (
    menu_board_id      BIGINT NOT NULL PRIMARY KEY,
    restaurant_id          BIGINT NOT NULL,
    template_board_id         BIGINT REFERENCES brand_menu_template_board(template_board_id),
    name                         VARCHAR(200) NOT NULL,
    board_type_code                 VARCHAR(40) NOT NULL
        CHECK (board_type_code IN ('a_la_carte','buffet','thali','combo','bar','breakfast','lunch','dinner',
                                    'kids','dessert','room_service','seasonal','catering')),
    description                        VARCHAR(1000),
    valid_from                            DATE,
    valid_to                                 DATE,
    is_active                                  BOOLEAN NOT NULL DEFAULT TRUE,
    display_sequence                              INT NOT NULL DEFAULT 0,
    created_at                                       TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                                          TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_menu_board_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT uq_menu_board_tenant UNIQUE (restaurant_id, menu_board_id)
);

-- A dated/timed instance of a board — how a buffet's contents can differ
-- from one day to the next while "Lunch Buffet" itself stays one stable,
-- priced offering.
CREATE TABLE menu_board_instance (
    board_instance_id   BIGINT NOT NULL PRIMARY KEY,
    menu_board_id            BIGINT NOT NULL,
    instance_date                 DATE NOT NULL,
    start_time                       TIME,
    end_time                            TIME,
    price_per_person                       DECIMAL(12,2),
    is_active                                 BOOLEAN NOT NULL DEFAULT TRUE,
    notes                                        VARCHAR(500),
    CONSTRAINT fk_menu_board_instance_board FOREIGN KEY (menu_board_id) REFERENCES menu_board(menu_board_id),
    CONSTRAINT uq_menu_board_instance UNIQUE NULLS NOT DISTINCT (menu_board_id, instance_date, start_time)
);

CREATE TABLE menu_category (
    menu_category_id    BIGINT NOT NULL PRIMARY KEY,
    restaurant_id           BIGINT NOT NULL,
    parent_category_id         BIGINT,
    name                           VARCHAR(200) NOT NULL,
    description                       VARCHAR(500),
    image_url                            VARCHAR(1000),
    display_sequence                        INT NOT NULL DEFAULT 0,
    is_active                                  BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_menu_category_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT uq_menu_category_tenant UNIQUE (restaurant_id, menu_category_id),
    CONSTRAINT fk_menu_category_parent FOREIGN KEY (restaurant_id, parent_category_id)
        REFERENCES menu_category(restaurant_id, menu_category_id)
);

-- NEW — neither source schema had this. The OCR pipeline supplies category
-- only as a flat leaf-level string with no parent info (see menu_item.
-- raw_category_text in Section 7). This table remembers each restaurant's
-- own text -> menu_category_id mapping once a human curates one, so the
-- NEXT OCR batch for that restaurant auto-applies known mappings instead
-- of making a curator redo the same judgment call every time.
CREATE TABLE category_text_alias (
    category_text_alias_id   BIGINT NOT NULL PRIMARY KEY,
    restaurant_id                 BIGINT NOT NULL,
    raw_text                         VARCHAR(150) NOT NULL,
    menu_category_id                    BIGINT NOT NULL,
    created_at                             TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_category_text_alias_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT fk_category_text_alias_category FOREIGN KEY (restaurant_id, menu_category_id)
        REFERENCES menu_category(restaurant_id, menu_category_id),
    CONSTRAINT uq_category_text_alias UNIQUE (restaurant_id, raw_text)
);

-- Which categories a given board exposes. Tenant-safety fix: the uploaded
-- schema's own docs (§28) flagged that a board and its categories should
-- share a restaurant but "cannot be enforced with the current key" — it
-- can, with the same composite-FK technique used above.
CREATE TABLE menu_board_category (
    restaurant_id     BIGINT NOT NULL,
    menu_board_id         BIGINT NOT NULL,
    menu_category_id         BIGINT NOT NULL,
    display_sequence            INT NOT NULL DEFAULT 0,
    PRIMARY KEY (menu_board_id, menu_category_id),
    CONSTRAINT fk_menu_board_category_board FOREIGN KEY (restaurant_id, menu_board_id)
        REFERENCES menu_board(restaurant_id, menu_board_id),
    CONSTRAINT fk_menu_board_category_category FOREIGN KEY (restaurant_id, menu_category_id)
        REFERENCES menu_category(restaurant_id, menu_category_id)
);


-- ----------------------------------------------------------------------------
-- SECTION 7: Menu item — the base "sellable thing"
-- Kept from the uploaded schema: a combo/thali/bar item is still a
-- menu_item underneath (Sections 11 and 12), not a duplicated parallel
-- table, so pricing/variants/availability/media work identically no
-- matter what kind of item it is.
--
-- Dietary/allergen modeling is the one place this file most deliberately
-- departs from the uploaded schema. is_jain / is_vegan / is_eggless stay
-- first-class NULLABLE columns — nullable, unlike the uploaded schema's
-- NOT NULL BOOLEAN columns, because OCR extraction cannot reliably read these
-- off a menu photo and a forced 1/0 means guessing. NULL means "not
-- established," not "confirmed false." The uploaded schema's remaining
-- flags (is_gluten_free, is_halal, is_onion_garlic_free, contains_nuts)
-- move to menu_item_tag (Section 2) instead of fixed columns — both
-- because they're a lower-frequency, open-ended list, and because
-- contains_nuts specifically is an allergen field: defaulting an unknown
-- allergen fact to 0 is the one modeling choice worth treating as a
-- real data-safety issue, not a style preference. A missing menu_item_tag
-- row correctly reads as "not asserted," never as "confirmed nut-free."
-- ----------------------------------------------------------------------------

CREATE TABLE menu_item (
    menu_item_id          BIGINT NOT NULL PRIMARY KEY,
    restaurant_id             BIGINT NOT NULL,
    menu_category_id             BIGINT,
    canonical_dish_id                BIGINT REFERENCES canonical_dish(canonical_dish_id),
    template_item_id                    BIGINT REFERENCES brand_menu_template_item(template_item_id),

    name                                    VARCHAR(250) NOT NULL,
    normalized_name                            VARCHAR(250) NOT NULL,
    description                                   VARCHAR(2000),

    -- Verbatim OCR leaf string; NULL once menu_category_id is curated.
    -- "Needs curation" is simply: WHERE menu_category_id IS NULL AND
    -- raw_category_text IS NOT NULL. Restored from the original khaustan
    -- schema — absent from the uploaded one despite the brief explicitly
    -- asking for a stated answer here.
    raw_category_text                                VARCHAR(150),

    food_classification_code                            VARCHAR(20) CHECK (food_classification_code IN ('veg','egg','non_veg')),
    protein_type_id                                        BIGINT REFERENCES protein_type(protein_type_id),
    is_jain                                                   BOOLEAN,
    is_vegan                                                    BOOLEAN,
    is_eggless                                                    BOOLEAN,
    spice_level                                                      SMALLINT CHECK (spice_level BETWEEN 1 AND 5),

    -- Groups items that were originally one displayed menu line (e.g.
    -- "Fried Rice — Veg/Paneer/Mushroom") before an upstream splitter (OCR
    -- today, possibly manual entry later) broke them into separate rows.
    -- NULL for items that were always a single line. Restored from the
    -- original khaustan schema; the brief explicitly asked for a stated
    -- decision here and the uploaded schema doesn't address it.
    split_group_key                                                     VARCHAR(64),

    is_bestseller                                                          BOOLEAN NOT NULL DEFAULT FALSE,
    is_recommended                                                           BOOLEAN NOT NULL DEFAULT FALSE,
    status_code                                                                VARCHAR(30) NOT NULL DEFAULT 'active'
                                                                                CHECK (status_code IN ('active','out_of_stock','retired')),

    -- NULL = still tracking the brand template's defaults; a sync job may
    -- push template changes down. Any other value = locally diverged and
    -- excluded from future automatic pushes for that item.
    inheritance_mode_code                                                       VARCHAR(30)
        CHECK (inheritance_mode_code IS NULL OR inheritance_mode_code IN ('inherit','overridden','standalone')),

    last_verified_at                                                              TIMESTAMP(3) WITHOUT TIME ZONE,
    verification_status_code                                                        VARCHAR(30) NOT NULL DEFAULT 'unverified'
                                                                                     CHECK (verification_status_code IN ('unverified','needs_review','verified')),

    created_at                                                                        TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                                                                          TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),

    CONSTRAINT fk_menu_item_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT uq_menu_item_tenant UNIQUE (restaurant_id, menu_item_id),
    CONSTRAINT fk_menu_item_category FOREIGN KEY (restaurant_id, menu_category_id)
        REFERENCES menu_category(restaurant_id, menu_category_id)
);

-- Now that menu_item exists, complete the menu_item_tag FK from Section 2.
ALTER TABLE menu_item_tag ADD CONSTRAINT fk_menu_item_tag_item
    FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id);

CREATE TABLE menu_item_name (
    menu_item_name_id   BIGINT NOT NULL PRIMARY KEY,
    menu_item_id             BIGINT NOT NULL,
    language_code                VARCHAR(20) NOT NULL,
    name                             VARCHAR(250) NOT NULL,
    normalized_name                     VARCHAR(250) NOT NULL,
    name_type_code                         VARCHAR(30) NOT NULL CHECK (name_type_code IN ('primary','alias','translation')),
    CONSTRAINT fk_menu_item_name_item FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id),
    CONSTRAINT uq_menu_item_name UNIQUE (menu_item_id, language_code, name_type_code, name)
);

CREATE TABLE menu_board_item (
    menu_board_item_id   BIGINT NOT NULL PRIMARY KEY,
    restaurant_id             BIGINT NOT NULL,
    menu_board_id                 BIGINT NOT NULL,
    menu_item_id                     BIGINT NOT NULL,
    menu_category_id                    BIGINT,
    display_sequence                       INT NOT NULL DEFAULT 0,
    is_featured                               BOOLEAN NOT NULL DEFAULT FALSE,
    valid_from                                   DATE,
    valid_to                                        DATE,
    CONSTRAINT fk_menu_board_item_board FOREIGN KEY (restaurant_id, menu_board_id)
        REFERENCES menu_board(restaurant_id, menu_board_id),
    CONSTRAINT fk_menu_board_item_item FOREIGN KEY (restaurant_id, menu_item_id)
        REFERENCES menu_item(restaurant_id, menu_item_id),
    CONSTRAINT fk_menu_board_item_category FOREIGN KEY (restaurant_id, menu_category_id)
        REFERENCES menu_category(restaurant_id, menu_category_id),
    CONSTRAINT uq_menu_board_item UNIQUE (menu_board_id, menu_item_id)
);

CREATE TABLE menu_board_instance_item (
    board_instance_item_id   BIGINT NOT NULL PRIMARY KEY,
    board_instance_id            BIGINT NOT NULL,
    menu_item_id                     BIGINT,
    item_name                            VARCHAR(150),   -- free text when not also sold as a standalone menu_item
    course_label                             VARCHAR(50),  -- 'starter' / 'main' / 'dessert'
    is_live_counter                              BOOLEAN NOT NULL DEFAULT FALSE,
    display_sequence                                 INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_menu_board_instance_item_instance FOREIGN KEY (board_instance_id) REFERENCES menu_board_instance(board_instance_id),
    CONSTRAINT fk_menu_board_instance_item_item FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id),
    CONSTRAINT ck_menu_board_instance_item CHECK (menu_item_id IS NOT NULL OR item_name IS NOT NULL)
);


-- ----------------------------------------------------------------------------
-- SECTION 8: Variants, pricing schedules, versioned prices, item charges
-- Kept from the uploaded schema: variant (portion/serving unit) is
-- separated from price (dated, service-mode- and schedule-aware), which
-- handles half/full, small/medium/large, 30/60/90ml, per-piece/kg/person
-- and market price uniformly, plus dine-in-vs-takeaway-vs-delivery pricing
-- and happy hour, with tax fields per price row.
-- ----------------------------------------------------------------------------

CREATE TABLE menu_item_variant (
    variant_id       BIGINT NOT NULL PRIMARY KEY,
    menu_item_id         BIGINT NOT NULL,
    variant_name             VARCHAR(150) NOT NULL,        -- 'Half', 'Full', '90ml', '1 kg', '12 pc'
    variant_code                 VARCHAR(50),
    pricing_basis_code               VARCHAR(40) NOT NULL
        CHECK (pricing_basis_code IN ('fixed','per_piece','per_plate','per_person','per_kg','per_100g','per_100ml','market_price')),
    quantity_value                       DECIMAL(12,4),
    quantity_unit_code                       VARCHAR(10) CHECK (quantity_unit_code IN ('g','kg','ml','l','pieces')),
    display_sequence                             INT NOT NULL DEFAULT 0,
    is_default                                       BOOLEAN NOT NULL DEFAULT FALSE,
    is_active                                            BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_menu_item_variant_item FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id)
);

-- Happy-hour / early-bird schedules — one mechanism reused for food and bar.
CREATE TABLE price_schedule (
    price_schedule_id   BIGINT NOT NULL PRIMARY KEY,
    name                    VARCHAR(150) NOT NULL,
    description                 VARCHAR(500),
    start_time                     TIME,
    end_time                          TIME,
    is_active                            BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE price_schedule_day (
    price_schedule_id   BIGINT NOT NULL,
    day_of_week              SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    PRIMARY KEY (price_schedule_id, day_of_week),
    CONSTRAINT fk_price_schedule_day_schedule FOREIGN KEY (price_schedule_id) REFERENCES price_schedule(price_schedule_id)
);

CREATE TABLE source_record (
    source_id       BIGINT NOT NULL PRIMARY KEY,
    source_type_code    VARCHAR(40) NOT NULL CHECK (source_type_code IN ('admin','owner','partner_api','ai_menu_extraction','imported')),
    external_reference       VARCHAR(500),
    source_uri                  VARCHAR(1000),
    created_at                     TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC')
);

-- Effective-dated price version. Multiple concurrently-valid rows for one
-- variant are expected and correct — e.g. a dine-in price and a takeaway
-- price both "current" at once, distinguished by service_mode_id, or a
-- happy-hour override distinguished by price_schedule_id.
--
-- This table is allowed to accumulate history (that's what makes price
-- alerts possible) but is NOT the unbounded analytical archive — keep an
-- operational retention window (90-180 days of superseded rows is a
-- reasonable starting point) and let change_event_outbox (Section 16) feed
-- the true long-term archive downstream, in the analytics/LLM store, not
-- here. A row with effective_to IS NULL is the current price for its
-- variant/service_mode/schedule combination.
CREATE TABLE menu_item_price (
    price_id           BIGINT NOT NULL PRIMARY KEY,
    variant_id             BIGINT NOT NULL,
    service_mode_id            BIGINT REFERENCES service_mode(service_mode_id),
    price_schedule_id              BIGINT REFERENCES price_schedule(price_schedule_id),
    price_amount                       DECIMAL(12,2),
    currency_code                          CHAR(3) NOT NULL DEFAULT 'INR',
    is_market_price                            BOOLEAN NOT NULL DEFAULT FALSE,
    tax_regime_code                                VARCHAR(40),   -- open/externally-driven; see docx appendix
    tax_inclusion_code                                 VARCHAR(30) CHECK (tax_inclusion_code IS NULL OR tax_inclusion_code IN ('inclusive','exclusive')),
    tax_rate                                               DECIMAL(7,4) CHECK (tax_rate IS NULL OR tax_rate >= 0),
    effective_from                                             TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL,
    effective_to                                                   TIMESTAMP(3) WITHOUT TIME ZONE,
    verification_status_code                                          VARCHAR(30)
                                                                       CHECK (verification_status_code IS NULL
                                                                              OR verification_status_code IN ('unverified','needs_review','verified')),
    source_id                                                             BIGINT REFERENCES source_record(source_id),
    created_at                                                                TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_menu_item_price_variant FOREIGN KEY (variant_id) REFERENCES menu_item_variant(variant_id),
    CONSTRAINT ck_menu_item_price_amount CHECK (
        (is_market_price = TRUE AND price_amount IS NULL)
        OR (is_market_price = FALSE AND price_amount IS NOT NULL AND price_amount >= 0)
    )
);

-- Packaging/delivery/other item-level charges, kept separate from the base
-- price so a packaging fee is never mistaken for the dish price. The
-- uploaded schema's version of this CHECK had a permissive escape clause
-- that silently allowed a mistyped calculation_type_code through with
-- amount and percentage both NULL — fixed here with a closed CHECK.
CREATE TABLE menu_item_charge (
    charge_id         BIGINT NOT NULL PRIMARY KEY,
    menu_item_id           BIGINT NOT NULL,
    service_mode_id            BIGINT REFERENCES service_mode(service_mode_id),
    charge_type_code               VARCHAR(40) NOT NULL,   -- 'packaging', 'service_charge', ... — open, see docx appendix
    calculation_type_code              VARCHAR(30) NOT NULL CHECK (calculation_type_code IN ('fixed','percentage')),
    amount                                  DECIMAL(12,2),
    percentage                                 DECIMAL(7,4),
    tax_regime_code                                VARCHAR(40),
    effective_from                                     TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL,
    effective_to                                           TIMESTAMP(3) WITHOUT TIME ZONE,
    is_active                                                  BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_menu_item_charge_item FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id),
    CONSTRAINT fk_menu_item_charge_service_mode FOREIGN KEY (service_mode_id) REFERENCES service_mode(service_mode_id),
    CONSTRAINT ck_menu_item_charge_value CHECK (
        (calculation_type_code = 'fixed' AND amount IS NOT NULL AND amount >= 0)
        OR (calculation_type_code = 'percentage' AND percentage IS NOT NULL AND percentage >= 0)
    )
);


-- ----------------------------------------------------------------------------
-- SECTION 9: Availability
-- ----------------------------------------------------------------------------

CREATE TABLE menu_item_availability (
    availability_id   BIGINT NOT NULL PRIMARY KEY,
    menu_item_id           BIGINT NOT NULL,
    day_of_week                SMALLINT CHECK (day_of_week IS NULL OR day_of_week BETWEEN 1 AND 7),
    start_time                     TIME,
    end_time                          TIME,
    effective_from                       DATE,
    effective_to                             DATE,
    max_quantity                                 INT CHECK (max_quantity IS NULL OR max_quantity >= 0),
    is_active                                        BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_menu_item_availability_item FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id)
);

CREATE TABLE menu_item_availability_override (
    override_id       BIGINT NOT NULL PRIMARY KEY,
    menu_item_id            BIGINT NOT NULL,
    override_date                DATE NOT NULL,
    start_time                       TIME,
    end_time                            TIME,
    status_code                             VARCHAR(30) NOT NULL CHECK (status_code IN ('sold_out','limited_quantity','special_availability','closed')),
    quantity_remaining                          INT CHECK (quantity_remaining IS NULL OR quantity_remaining >= 0),
    reason                                          VARCHAR(300),
    CONSTRAINT fk_menu_item_availability_override_item FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id),
    CONSTRAINT uq_menu_item_availability_override UNIQUE (menu_item_id, override_date)
);


-- ----------------------------------------------------------------------------
-- SECTION 10: Add-ons / customization — NEW SECTION, present in neither
-- source schema in this form. The uploaded schema's bundle mechanism
-- (Section 11) covers combo/thali component *selection*, but not a
-- modifier on a single standalone dish — extra cheese, spice level, bread
-- choice — which the brief explicitly asked for.
-- ----------------------------------------------------------------------------

CREATE TABLE addon_group (
    addon_group_id   BIGINT NOT NULL PRIMARY KEY,
    restaurant_id         BIGINT NOT NULL,
    name                      VARCHAR(100) NOT NULL,   -- 'Spice Level', 'Toppings', 'Bread Choice'
    selection_type               VARCHAR(10) NOT NULL CHECK (selection_type IN ('single','multiple')),
    is_required                      BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_addon_group_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id)
);

CREATE TABLE addon_option (
    addon_option_id   BIGINT NOT NULL PRIMARY KEY,
    addon_group_id        BIGINT NOT NULL,
    name                      VARCHAR(100) NOT NULL,    -- 'Extra Cheese', 'Naan', 'With Tobacco'
    extra_price                   DECIMAL(10,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_addon_option_group FOREIGN KEY (addon_group_id) REFERENCES addon_group(addon_group_id)
);

CREATE TABLE menu_item_addon_group (
    menu_item_id     BIGINT NOT NULL,
    addon_group_id       BIGINT NOT NULL,
    PRIMARY KEY (menu_item_id, addon_group_id),
    CONSTRAINT fk_menu_item_addon_group_item FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id),
    CONSTRAINT fk_menu_item_addon_group_group FOREIGN KEY (addon_group_id) REFERENCES addon_group(addon_group_id)
);


-- ----------------------------------------------------------------------------
-- SECTION 11: Bundles — combo / thali
-- Kept from the uploaded schema: a bundle is a 1:1 extension of a
-- menu_item, so it gets normal variants/prices/availability/media for
-- free. bundle_type_code deliberately excludes 'buffet' — a buffet whose
-- contents vary by date is represented at the board level (Section 6:
-- menu_board_instance / menu_board_instance_item), not as a bundle, since
-- a bundle's component list isn't date-varying by design. This divides
-- the two cleanly instead of leaving both bundle_type_code and
-- board_type_code able to say "buffet," which is confusing and was
-- under-specified in the uploaded schema (bundle_type_code had no
-- documented value list at all).
-- ----------------------------------------------------------------------------

CREATE TABLE bundle (
    bundle_id          BIGINT NOT NULL PRIMARY KEY,
    menu_item_id            BIGINT NOT NULL UNIQUE,
    bundle_type_code            VARCHAR(30) NOT NULL CHECK (bundle_type_code IN ('combo','thali','platter','meal')),
    is_customizable                 BOOLEAN NOT NULL DEFAULT FALSE,
    description                        VARCHAR(1000),
    CONSTRAINT fk_bundle_menu_item FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id)
);

-- A selectable/refillable slot, e.g. "Choose your sabzi" or "Roti (refills
-- included)". refill_policy_code is more expressive than a plain
-- unlimited/not-unlimited boolean — it can distinguish "unlimited",
-- "limited free refills", "paid refill" and "none" without a schema change
-- if a new refill model shows up later.
CREATE TABLE bundle_group (
    bundle_group_id   BIGINT NOT NULL PRIMARY KEY,
    bundle_id             BIGINT NOT NULL,
    name                      VARCHAR(150) NOT NULL,
    selection_min                 INT NOT NULL DEFAULT 1,
    selection_max                     INT NOT NULL DEFAULT 1,
    refill_policy_code                    VARCHAR(30) CHECK (refill_policy_code IS NULL
                                           OR refill_policy_code IN ('none','unlimited','limited_free_refills','paid_refill')),
    refill_limit                              INT CHECK (refill_limit IS NULL OR refill_limit >= 0),
    display_sequence                              INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_bundle_group_bundle FOREIGN KEY (bundle_id) REFERENCES bundle(bundle_id),
    CONSTRAINT ck_bundle_group_selection CHECK (selection_min >= 0 AND selection_max >= selection_min)
);

CREATE TABLE bundle_component (
    bundle_component_id   BIGINT NOT NULL PRIMARY KEY,
    bundle_id                  BIGINT NOT NULL,
    bundle_group_id                BIGINT REFERENCES bundle_group(bundle_group_id),
    component_menu_item_id             BIGINT NOT NULL,
    quantity                               DECIMAL(12,3) NOT NULL CHECK (quantity > 0),
    display_sequence                           INT NOT NULL DEFAULT 0,
    is_default                                     BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_bundle_component_bundle FOREIGN KEY (bundle_id) REFERENCES bundle(bundle_id),
    CONSTRAINT fk_bundle_component_item FOREIGN KEY (component_menu_item_id) REFERENCES menu_item(menu_item_id)
);

-- ----------------------------------------------------------------------------
-- SECTION 12: Bar / alcohol extension
-- ----------------------------------------------------------------------------
CREATE TABLE bar_product_type (
    bar_product_type_id		INT NOT NULL PRIMARY KEY,
    bar_product_code		VARCHAR(40) NOT NULL UNIQUE,
    label			VARCHAR(100) NOT NULL,
    is_alchohol			BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE bar_product (
    bar_product_id   BIGINT NOT NULL PRIMARY KEY,
    product_type_id    	int NOT NULL ,
    brand_name                VARCHAR(200),
    product_name                  VARCHAR(250) NOT NULL,
    origin_code                       VARCHAR(40),   -- open — e.g. 'imfl', 'scotch', 'imported'; see docx appendix
    abv_percent                          DECIMAL(6,3) CHECK (abv_percent IS NULL OR (abv_percent BETWEEN 0 AND 100)),
    spirit_type_code                         VARCHAR(40),   -- open — e.g. 'single_malt', 'bourbon'
    is_imported                                  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at                                       TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                                          TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_bar_product_type_id FOREIGN KEY (product_type_id) REFERENCES bar_product_type(bar_product_type_id)
);

CREATE TABLE bar_menu_item (
    menu_item_id          BIGINT NOT NULL PRIMARY KEY,
    bar_product_id             BIGINT REFERENCES bar_product(bar_product_id),
    bar_item_type_code             VARCHAR(40) NOT NULL ,
    cocktail_base_required             BOOLEAN NOT NULL DEFAULT FALSE,
    notes                                  VARCHAR(1000),
    CONSTRAINT fk_bar_menu_item_item FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id)
);

-- Selectable base spirit for a cocktail — "choice of gin/vodka/rum, with a
-- possible upcharge for a premium base."
CREATE TABLE cocktail_base_option (
    cocktail_base_option_id   BIGINT NOT NULL PRIMARY KEY,
    cocktail_menu_item_id         BIGINT NOT NULL,
    bar_product_id                    BIGINT NOT NULL,
    additional_price                      DECIMAL(12,2) CHECK (additional_price IS NULL OR additional_price >= 0),
    is_default                                BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_cocktail_base_option_item FOREIGN KEY (cocktail_menu_item_id) REFERENCES bar_menu_item(menu_item_id),
    CONSTRAINT fk_cocktail_base_option_product FOREIGN KEY (bar_product_id) REFERENCES bar_product(bar_product_id)
);


-- ----------------------------------------------------------------------------
-- SECTION 13: Media
-- Binary images stay in object storage; only metadata and a URI live here.
-- ----------------------------------------------------------------------------

CREATE TABLE media_asset (
    media_asset_id   BIGINT NOT NULL PRIMARY KEY,
    storage_uri           VARCHAR(1000) NOT NULL,
    media_type_code           VARCHAR(30) NOT NULL CHECK (media_type_code IN ('photo','logo','menu_scan','video')),
    width                         INT,
    height                            INT,
    checksum                             VARCHAR(128),
    created_at                               TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC')
);

CREATE TABLE restaurant_media (
    restaurant_id     BIGINT NOT NULL,
    media_asset_id        BIGINT NOT NULL,
    display_sequence          INT NOT NULL DEFAULT 0,
    media_role_code               VARCHAR(30) NOT NULL CHECK (media_role_code IN ('cover','gallery','logo','menu_scan')),
    PRIMARY KEY (restaurant_id, media_asset_id),
    CONSTRAINT fk_restaurant_media_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT fk_restaurant_media_asset FOREIGN KEY (media_asset_id) REFERENCES media_asset(media_asset_id)
);

CREATE TABLE menu_item_media (
    menu_item_id     BIGINT NOT NULL,
    media_asset_id       BIGINT NOT NULL,
    display_sequence         INT NOT NULL DEFAULT 0,
    media_role_code              VARCHAR(30) NOT NULL CHECK (media_role_code IN ('cover','gallery')),
    PRIMARY KEY (menu_item_id, media_asset_id),
    CONSTRAINT fk_menu_item_media_item FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id),
    CONSTRAINT fk_menu_item_media_asset FOREIGN KEY (media_asset_id) REFERENCES media_asset(media_asset_id)
);

CREATE TABLE menu_category_media (
    menu_category_id   BIGINT NOT NULL,
    media_asset_id          BIGINT NOT NULL,
    display_sequence            INT NOT NULL DEFAULT 0,
    media_role_code                 VARCHAR(30) NOT NULL CHECK (media_role_code IN ('cover','gallery')),
    PRIMARY KEY (menu_category_id, media_asset_id),
    CONSTRAINT fk_menu_category_media_category FOREIGN KEY (menu_category_id) REFERENCES menu_category(menu_category_id),
    CONSTRAINT fk_menu_category_media_asset FOREIGN KEY (media_asset_id) REFERENCES media_asset(media_asset_id)
);


-- ----------------------------------------------------------------------------
-- SECTION 14: OCR / AI menu extraction provenance
-- Confidence is tracked separately for an item's existence/name versus a
-- specific price's extraction, since OCR can be sure about one and not the
-- other. page_number (not filename order) is authoritative, so page 2
-- correctly precedes page 10.
-- ----------------------------------------------------------------------------

CREATE TABLE menu_extraction_batch (
    extraction_batch_id   BIGINT NOT NULL PRIMARY KEY,
    restaurant_id              BIGINT NOT NULL,
    source_id                      BIGINT NOT NULL,
    extractor_version                  VARCHAR(100),
    started_at                             TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL,
    completed_at                               TIMESTAMP(3) WITHOUT TIME ZONE,
    status_code                                    VARCHAR(30) NOT NULL CHECK (status_code IN ('running','completed','failed','partially_completed')),
    overall_confidence                                 DECIMAL(6,5) CHECK (overall_confidence IS NULL OR (overall_confidence BETWEEN 0 AND 1)),
    CONSTRAINT fk_menu_extraction_batch_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT fk_menu_extraction_batch_source FOREIGN KEY (source_id) REFERENCES source_record(source_id)
);

CREATE TABLE menu_extraction_image (
    extraction_image_id   BIGINT NOT NULL PRIMARY KEY,
    extraction_batch_id        BIGINT NOT NULL,
    media_asset_id                 BIGINT NOT NULL,
    page_number                        INT NOT NULL CHECK (page_number > 0),
    original_filename                      VARCHAR(500),
    extracted_text_checksum                    VARCHAR(128),
    CONSTRAINT fk_menu_extraction_image_batch FOREIGN KEY (extraction_batch_id) REFERENCES menu_extraction_batch(extraction_batch_id),
    CONSTRAINT fk_menu_extraction_image_asset FOREIGN KEY (media_asset_id) REFERENCES media_asset(media_asset_id),
    CONSTRAINT uq_menu_extraction_image_page UNIQUE (extraction_batch_id, page_number)
);

CREATE TABLE menu_item_source (
    menu_item_id     BIGINT NOT NULL,
    source_id            BIGINT NOT NULL,
    extraction_batch_id      BIGINT REFERENCES menu_extraction_batch(extraction_batch_id),
    confidence                    DECIMAL(6,5) CHECK (confidence IS NULL OR (confidence BETWEEN 0 AND 1)),
    verification_status_code          VARCHAR(30) NOT NULL DEFAULT 'unverified'
                                       CHECK (verification_status_code IN ('unverified','needs_review','verified')),
    verified_at                               TIMESTAMP(3) WITHOUT TIME ZONE,
    PRIMARY KEY (menu_item_id, source_id),
    CONSTRAINT fk_menu_item_source_item FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id),
    CONSTRAINT fk_menu_item_source_source FOREIGN KEY (source_id) REFERENCES source_record(source_id)
);

CREATE TABLE menu_item_price_source (
    price_id       BIGINT NOT NULL,
    source_id          BIGINT NOT NULL,
    extraction_batch_id    BIGINT REFERENCES menu_extraction_batch(extraction_batch_id),
    confidence                  DECIMAL(6,5) CHECK (confidence IS NULL OR (confidence BETWEEN 0 AND 1)),
    PRIMARY KEY (price_id, source_id),
    CONSTRAINT fk_menu_item_price_source_price FOREIGN KEY (price_id) REFERENCES menu_item_price(price_id),
    CONSTRAINT fk_menu_item_price_source_source FOREIGN KEY (source_id) REFERENCES source_record(source_id)
);


-- ----------------------------------------------------------------------------
-- SECTION 15: Delivery capability
-- Three layers: does the outlet deliver at all; which third-party
-- providers serve it; can a specific item be delivered by a specific
-- provider. This is availability/capability metadata for display, not an
-- order-execution or dynamic-pricing engine — those stay in the separate
-- Ordering and Delivery services.
-- ----------------------------------------------------------------------------

CREATE TABLE delivery_provider (
    delivery_provider_id   BIGINT NOT NULL PRIMARY KEY,
    provider_code               VARCHAR(50) NOT NULL UNIQUE,
    provider_name                   VARCHAR(150) NOT NULL,
    provider_type_code                  VARCHAR(30) NOT NULL CHECK (provider_type_code IN ('self','third_party')),
    is_active                               BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                                  TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                                     TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC')
);

CREATE TABLE restaurant_delivery (
    restaurant_id                    BIGINT NOT NULL PRIMARY KEY,
    delivery_available                    BOOLEAN NOT NULL DEFAULT FALSE,
    self_delivery_available                   BOOLEAN NOT NULL DEFAULT FALSE,
    self_delivery_min_order_amount                DECIMAL(12,2) CHECK (self_delivery_min_order_amount IS NULL OR self_delivery_min_order_amount >= 0),
    currency_code                                     CHAR(3) DEFAULT 'INR',
    last_verified_at                                      TIMESTAMP(3) WITHOUT TIME ZONE,
    status_code                                               VARCHAR(30) NOT NULL DEFAULT 'active' CHECK (status_code IN ('active','inactive')),
    created_at                                                    TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                                                        TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_restaurant_delivery_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id)
);

CREATE TABLE restaurant_delivery_provider (
    restaurant_delivery_provider_id   BIGINT NOT NULL PRIMARY KEY,
    restaurant_id                          BIGINT NOT NULL,
    delivery_provider_id                       BIGINT NOT NULL,
    is_available                                   BOOLEAN NOT NULL DEFAULT TRUE,
    minimum_order_amount                               DECIMAL(12,2) CHECK (minimum_order_amount IS NULL OR minimum_order_amount >= 0),
    base_delivery_charge                                   DECIMAL(12,2) CHECK (base_delivery_charge IS NULL OR base_delivery_charge >= 0),
    delivery_charge_type_code                                  VARCHAR(30) NOT NULL CHECK (delivery_charge_type_code IN ('fixed','percentage')),
    delivery_charge_percentage                                     DECIMAL(7,4) CHECK (delivery_charge_percentage IS NULL OR delivery_charge_percentage >= 0),
    free_delivery_min_order_amount                                     DECIMAL(12,2) CHECK (free_delivery_min_order_amount IS NULL OR free_delivery_min_order_amount >= 0),
    currency_code                                                          CHAR(3) DEFAULT 'INR',
    effective_from                                                             TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL,
    effective_to                                                                   TIMESTAMP(3) WITHOUT TIME ZONE,
    last_verified_at                                                                   TIMESTAMP(3) WITHOUT TIME ZONE,
    created_at                                                                             TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                                                                                 TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_restaurant_delivery_provider_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT fk_restaurant_delivery_provider_provider FOREIGN KEY (delivery_provider_id) REFERENCES delivery_provider(delivery_provider_id),
    CONSTRAINT uq_restaurant_delivery_provider_version UNIQUE (restaurant_id, delivery_provider_id, effective_from)
);

-- self_delivery_available = 0 does not mean "no delivery" — a
-- third-party provider may still deliver. delivery_available = 0 on
-- restaurant_delivery means no configured delivery capability at all.
CREATE TABLE menu_item_delivery (
    menu_item_delivery_id   BIGINT NOT NULL PRIMARY KEY,
    menu_item_id                 BIGINT NOT NULL,
    delivery_provider_id             BIGINT REFERENCES delivery_provider(delivery_provider_id),
    delivery_status_code                 VARCHAR(30) NOT NULL CHECK (delivery_status_code IN ('available','not_available','conditional')),
    minimum_order_amount                     DECIMAL(12,2) CHECK (minimum_order_amount IS NULL OR minimum_order_amount >= 0),
    reason_code                                  VARCHAR(40),   -- open — e.g. 'quality', 'buffet', 'packaging_unsuitable'
    effective_from                                   TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL,
    effective_to                                         TIMESTAMP(3) WITHOUT TIME ZONE,
    last_verified_at                                         TIMESTAMP(3) WITHOUT TIME ZONE,
    CONSTRAINT fk_menu_item_delivery_item FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id)
);

-- ----------------------------------------------------------------------------
-- SECTION 16: Change events — bounded transactional outbox
-- Whenever a price/menu/restaurant change commits, a row is written here in the SAME
-- transaction. A separate publisher polls status = 'pending', forwards each event
-- to the event bus that the search index, price-alert processing, and the future
-- LLM-training pipeline all subscribe to, then marks it published. Published rows
-- past expires_at get purged by a retention job — this table is a reliable relay,
-- not the archive itself; the archive is built downstream, from the events it receives.
-- ----------------------------------------------------------------------------

CREATE TABLE change_event_outbox (
    event_id           BIGINT NOT NULL PRIMARY KEY,
    aggregate_type          VARCHAR(50) NOT NULL
                             CHECK (aggregate_type IN ('restaurant','menu_item','menu_item_variant','menu_item_price','bundle','menu_board')),
    aggregate_id                BIGINT NOT NULL,
    event_type                      VARCHAR(50) NOT NULL
                                     CHECK (event_type IN ('restaurant_created','restaurant_updated','item_added','item_removed',
                                                            'item_updated','price_changed','menu_updated')),
    occurred_at                         TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    payload                                 TEXT NOT NULL,
    publish_status_code                         VARCHAR(30) NOT NULL DEFAULT 'pending' CHECK (publish_status_code IN ('pending','published','failed')),
    attempt_count                                   INT NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    next_attempt_at                                     TIMESTAMP(3) WITHOUT TIME ZONE,
    published_at                                            TIMESTAMP(3) WITHOUT TIME ZONE,
    expires_at                                                  TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL
);


-- ============================================================================
-- SECTION 17: Indexes
-- ============================================================================

CREATE INDEX ix_restaurant_establishment ON restaurant(establishment_id);
CREATE INDEX ix_restaurant_brand ON restaurant(brand_id);
CREATE INDEX ix_restaurant_status ON restaurant(status_code);
CREATE INDEX ix_restaurant_veg_status ON restaurant(veg_nonveg_status);
CREATE INDEX ix_restaurant_has_bar ON restaurant(has_bar);
CREATE INDEX ix_restaurant_normalized_name ON restaurant(normalized_name);
CREATE INDEX ix_restaurant_listing_tier ON restaurant(listing_tier_code);
CREATE INDEX ix_establishment_name_postal ON establishment(normalized_name, postal_code);
CREATE INDEX ix_establishment_geo ON establishment(latitude, longitude);

CREATE INDEX ix_restaurant_phone_restaurant ON restaurant_phone(restaurant_id);
CREATE INDEX ix_external_identity_restaurant ON restaurant_external_identity(restaurant_id);

CREATE INDEX ix_restaurant_tag_tag ON restaurant_tag(tag_id, restaurant_id);
CREATE INDEX ix_menu_item_tag_tag ON menu_item_tag(tag_id, menu_item_id);

CREATE INDEX ix_restaurant_service_mode_active ON restaurant_service_mode(restaurant_id, is_active);
CREATE INDEX ix_restaurant_hours ON restaurant_hours(restaurant_id, day_of_week, slot_sequence);
CREATE INDEX ix_holiday_hours ON restaurant_holiday_hours(restaurant_id, holiday_date);

CREATE INDEX ix_brand_template_brand ON brand_menu_template(brand_id, is_active);
CREATE INDEX ix_template_item_template ON brand_menu_template_item(template_id);
CREATE INDEX ix_template_board_template ON brand_menu_template_board(template_id);

CREATE INDEX ix_canonical_dish_normalized ON canonical_dish(normalized_name);
CREATE INDEX ix_canonical_dish_classification ON canonical_dish(food_classification_code);
CREATE INDEX ix_canonical_dish_jain ON canonical_dish(is_jain);
CREATE INDEX ix_canonical_dish_name_normalized ON canonical_dish_name(normalized_name);

CREATE INDEX ix_menu_board_restaurant_active ON menu_board(restaurant_id, is_active, display_sequence);
CREATE INDEX ix_menu_board_type_active ON menu_board(board_type_code, is_active);
CREATE INDEX ix_menu_board_instance_date ON menu_board_instance(menu_board_id, instance_date);

CREATE INDEX ix_menu_category_tree ON menu_category(restaurant_id, parent_category_id, display_sequence);
CREATE INDEX ix_category_text_alias_lookup ON category_text_alias(restaurant_id, raw_text);

CREATE INDEX ix_menu_item_restaurant_status ON menu_item(restaurant_id, status_code);
CREATE INDEX ix_menu_item_canonical ON menu_item(canonical_dish_id);
CREATE INDEX ix_menu_item_normalized ON menu_item(normalized_name);
CREATE INDEX ix_menu_item_classification ON menu_item(food_classification_code);
CREATE INDEX ix_menu_item_protein ON menu_item(protein_type_id);
CREATE INDEX ix_menu_item_jain ON menu_item(is_jain);
CREATE INDEX ix_menu_item_vegan ON menu_item(is_vegan);
CREATE INDEX ix_menu_item_template ON menu_item(template_item_id);
CREATE INDEX ix_menu_item_split_group ON menu_item(split_group_key);
CREATE INDEX ix_menu_item_needs_curation ON menu_item(restaurant_id, menu_category_id);
CREATE INDEX ix_menu_item_name_normalized ON menu_item_name(normalized_name);

CREATE INDEX ix_menu_board_item_item ON menu_board_item(menu_item_id);
CREATE INDEX ix_menu_board_item_display ON menu_board_item(menu_board_id, display_sequence);
CREATE INDEX ix_menu_board_instance_item_item ON menu_board_instance_item(menu_item_id);

CREATE INDEX ix_menu_item_variant_item_active ON menu_item_variant(menu_item_id, is_active);

CREATE INDEX ix_menu_item_price_current ON menu_item_price(variant_id, effective_from, effective_to);
CREATE INDEX ix_menu_item_price_service ON menu_item_price(variant_id, service_mode_id, effective_from);
CREATE INDEX ix_menu_item_price_schedule ON menu_item_price(price_schedule_id, effective_from);

CREATE INDEX ix_menu_item_charge_item_service ON menu_item_charge(menu_item_id, service_mode_id, effective_from);

CREATE INDEX ix_menu_item_availability ON menu_item_availability(menu_item_id, day_of_week, start_time);
CREATE INDEX ix_menu_item_availability_override ON menu_item_availability_override(menu_item_id, override_date);

CREATE INDEX ix_addon_group_restaurant ON addon_group(restaurant_id);

CREATE INDEX ix_bundle_group_bundle ON bundle_group(bundle_id, display_sequence);
CREATE INDEX ix_bundle_component_bundle ON bundle_component(bundle_id, display_sequence);
CREATE INDEX ix_bundle_component_item ON bundle_component(component_menu_item_id);

CREATE INDEX ix_bar_product_type ON bar_product(product_type_id);
CREATE INDEX ix_bar_menu_item_product ON bar_menu_item(bar_product_id);
CREATE INDEX ix_cocktail_base_option_cocktail ON cocktail_base_option(cocktail_menu_item_id, is_default);

CREATE INDEX ix_restaurant_media_role ON restaurant_media(restaurant_id, media_role_code);
CREATE INDEX ix_menu_item_media_role ON menu_item_media(menu_item_id, media_role_code);

CREATE INDEX ix_extraction_batch_restaurant ON menu_extraction_batch(restaurant_id, started_at);
CREATE INDEX ix_extraction_image_batch ON menu_extraction_image(extraction_batch_id, page_number);
CREATE INDEX ix_menu_item_source_batch ON menu_item_source(extraction_batch_id);

CREATE INDEX ix_restaurant_delivery_provider_restaurant ON restaurant_delivery_provider(restaurant_id, is_available, effective_from);
CREATE INDEX ix_menu_item_delivery_item ON menu_item_delivery(menu_item_id, delivery_provider_id, effective_from);

CREATE INDEX ix_change_event_outbox_publish ON change_event_outbox(publish_status_code, next_attempt_at);
CREATE INDEX ix_change_event_outbox_aggregate ON change_event_outbox(aggregate_type, aggregate_id);
CREATE INDEX ix_change_event_outbox_expiry ON change_event_outbox(expires_at);


