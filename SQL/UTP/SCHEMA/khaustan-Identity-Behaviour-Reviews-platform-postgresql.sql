/* ============================================================================
   KHAUSTAN.COM — Identity, Behavior, Reviews Databases PLATFORM DEPLOYMENT SCRIPT (POSTGRESQL)
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
     2. KhaustanIdentity         -- registered users + guest sessions (4 tables)
     3. KhaustanSearchBehavior   -- search queries, impressions, clicks (3 tables)
     4. KhaustanReviews          -- reviews, dish tags, replies, moderation (7 tables)
   ============================================================================ */

/* ============================================================================
   DATABASE — KhaustanIdentity
   Registered users and guest sessions. 4 tables.
   ============================================================================ */
SELECT format('CREATE DATABASE %I', 'KhaustanIdentity')
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_database
    WHERE datname = 'KhaustanIdentity'
)\gexec

\connect "KhaustanIdentity"

CREATE TABLE auth_provider (
    auth_provider_id   BIGINT NOT NULL PRIMARY KEY,
    code                  VARCHAR(40) NOT NULL UNIQUE,   -- 'password','google','facebook','apple','otp_phone','otp_email', ...
    name                     VARCHAR(100) NOT NULL,
    provider_type_code          VARCHAR(20) NOT NULL CHECK (provider_type_code IN ('password','oauth','otp')),
    is_active                      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE identity_user (
    user_id            BIGINT NOT NULL PRIMARY KEY,
    display_name          VARCHAR(150) NOT NULL,
    email                     VARCHAR(250),                -- nullable: a phone/OTP-only or social-only user may never supply one
    email_verified_at            TIMESTAMP(3) WITHOUT TIME ZONE,
    phone_number                     VARCHAR(20),
    phone_verified_at                    TIMESTAMP(3) WITHOUT TIME ZONE,

    -- Lightweight classification, not a full permissions engine — the
    -- brainstormed "micro-influencer program" feature needs a slot, but a
    -- full cross-domain RBAC/permissions model is out of scope here.
    account_type_code                       VARCHAR(30) NOT NULL DEFAULT 'standard'
                                             CHECK (account_type_code IN ('standard','micro_influencer','verified')),

    status_code                                 VARCHAR(20) NOT NULL DEFAULT 'active'
                                                 CHECK (status_code IN ('active','suspended','deactivated','deleted')),
    last_login_at                                   TIMESTAMP(3) WITHOUT TIME ZONE,
    created_at                                          TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                                              TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),

    CONSTRAINT ck_identity_user_has_contact CHECK (email IS NOT NULL OR phone_number IS NOT NULL)
);

-- A user can link more than one sign-in method to the same account (Google
-- AND phone OTP, for instance). provider_user_id is the external subject
-- ID from that provider; credential_hash is only ever populated for the
-- 'password' provider.
CREATE TABLE user_auth_method (
    auth_method_id     BIGINT NOT NULL PRIMARY KEY,
    user_id                BIGINT NOT NULL,
    auth_provider_id           BIGINT NOT NULL,
    provider_user_id               VARCHAR(250),
    credential_hash                    VARCHAR(300),
    is_primary                             BOOLEAN NOT NULL DEFAULT FALSE,
    linked_at                                  TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_user_auth_method_user FOREIGN KEY (user_id) REFERENCES identity_user(user_id),
    CONSTRAINT fk_user_auth_method_provider FOREIGN KEY (auth_provider_id) REFERENCES auth_provider(auth_provider_id),
    CONSTRAINT uq_user_auth_method_external UNIQUE NULLS NOT DISTINCT (auth_provider_id, provider_user_id)
);

-- Anonymous browsing/search, no login. Deliberately NOT the same table as
-- identity_user — a guest is not a partial user record, it's a different
-- kind of thing with a different privacy posture (no name, no email, and
-- an expiry). session_token is the opaque, client-facing identifier (a
-- cookie or local-storage value); guest_session_id is the internal key
-- other local tables reference.
--
-- IP-derived location is coarse by nature (city-level at best, sometimes
-- only country/region, and distorted by VPNs/mobile carriers) — store it
-- as an approximation, never represent it as GPS-precise.
--
-- IP address is still personal data under DPDP even with no email attached
-- — it's an identifier the law treats as personal data, not exempt data
-- just because a name is missing. expires_at gives every guest session a
-- retention limit rather than keeping it indefinitely by default.
CREATE TABLE guest_session (
    guest_session_id     BIGINT NOT NULL PRIMARY KEY,
    session_token            VARCHAR(128) NOT NULL UNIQUE,
    ip_address                   VARCHAR(45) NOT NULL,   -- IPv6-safe length
    derived_country_code             CHAR(2),
    derived_region                       VARCHAR(100),
    derived_city                             VARCHAR(100),
    derived_latitude                             DECIMAL(9,6),
    derived_longitude                                DECIMAL(9,6),
    user_agent                                           VARCHAR(500),

    -- Set once a guest signs up mid-session, so search/click history can
    -- be attributed to the resulting account without being rewritten —
    -- Search & Behavior keeps its original guest_session_id rows and a
    -- consuming query can join through this column when it needs to.
    converted_to_user_id                                     BIGINT REFERENCES identity_user(user_id),

    first_seen_at                                                TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    last_seen_at                                                     TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    expires_at                                                           TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL
);

CREATE INDEX ix_identity_user_email ON identity_user(email);
CREATE INDEX ix_identity_user_phone ON identity_user(phone_number);
CREATE INDEX ix_identity_user_status ON identity_user(status_code);
CREATE INDEX ix_user_auth_method_user ON user_auth_method(user_id);
CREATE INDEX ix_guest_session_token ON guest_session(session_token);
CREATE INDEX ix_guest_session_expiry ON guest_session(expires_at);
CREATE INDEX ix_guest_session_converted ON guest_session(converted_to_user_id);
/* ============================================================================
   DATABASE — KhaustanSearchBehavior
   Search queries, result impressions, click events. 3 tables. See in-file note: no outbox here on purpose (rows are immutable events).
   ============================================================================ */
SELECT format('CREATE DATABASE %I', 'KhaustanSearchBehavior')
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_database
    WHERE datname = 'KhaustanSearchBehavior'
)\gexec

\connect "KhaustanSearchBehavior"

CREATE TABLE search_query_log (
    search_query_id     BIGINT NOT NULL PRIMARY KEY,
    user_id                 BIGINT,                 -- soft reference to identity_user; NULL for a guest search
    guest_session_id            BIGINT,              -- soft reference to guest_session; NULL for a logged-in search

    raw_query_text                  VARCHAR(500),    -- what was actually typed or spoken; NULL for a filter-only search
    normalized_query_text               VARCHAR(500),
    query_type_code                         VARCHAR(30) NOT NULL
                                             CHECK (query_type_code IN ('text','voice','filter_only','dish_craving','mood')),

    -- Open-shaped filter state (veg/non-veg, price band, cuisine, area,
    -- open-now, dietary tags, ...) as a text/JSON payload rather than one
    -- column per filter — the filter list is still growing (Section on
    -- amenities/filters in Restaurant & Menu is explicitly open-ended), so
    -- this stays additive the same way that one is.
    applied_filters                             TEXT,

    result_count                                    INT CHECK (result_count IS NULL OR result_count >= 0),
    search_latitude                                     DECIMAL(9,6),   -- the searcher's location AT THIS SEARCH, which can move within a session
    search_longitude                                        DECIMAL(9,6),
    platform_code                                               VARCHAR(20),   -- 'ios','android','web', ...
    searched_at                                                     TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),

    CONSTRAINT ck_search_query_log_actor CHECK (user_id IS NOT NULL OR guest_session_id IS NOT NULL)
);

-- What was actually shown for a search, and where it ranked — the "not
-- clicked" half of the signal, without which click-through data alone
-- overstates relevance.
CREATE TABLE search_result_impression (
    impression_id       BIGINT NOT NULL PRIMARY KEY,
    search_query_id         BIGINT NOT NULL,               -- local FK — same service, same database
    restaurant_id               BIGINT NOT NULL,            -- soft reference to Restaurant & Menu
    menu_item_id                    BIGINT,                 -- soft reference; NULL when the result is restaurant-level, not dish-level
    rank_position                       INT NOT NULL CHECK (rank_position > 0),
    shown_at                                TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_search_result_impression_query FOREIGN KEY (search_query_id) REFERENCES search_query_log(search_query_id)
);

-- A tap/click on anything — a search result, a favorites entry, a category
-- browse page. search_query_id is NULL when the click didn't originate
-- from a search (e.g. browsing a category listing directly).
CREATE TABLE click_event (
    click_id            BIGINT NOT NULL PRIMARY KEY,
    user_id                 BIGINT,
    guest_session_id            BIGINT,
    search_query_id                 BIGINT,             -- local FK, nullable
    restaurant_id                       BIGINT NOT NULL,  -- soft reference
    menu_item_id                            BIGINT,       -- soft reference, nullable

    click_type_code                             VARCHAR(30) NOT NULL
        CHECK (click_type_code IN ('view_restaurant','view_menu_item','call','whatsapp','directions','website','favorite','share')),

    clicked_at                                          TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),

    CONSTRAINT fk_click_event_query FOREIGN KEY (search_query_id) REFERENCES search_query_log(search_query_id),
    CONSTRAINT ck_click_event_actor CHECK (user_id IS NOT NULL OR guest_session_id IS NOT NULL)
);

CREATE INDEX ix_search_query_log_user ON search_query_log(user_id, searched_at);
CREATE INDEX ix_search_query_log_guest ON search_query_log(guest_session_id, searched_at);
CREATE INDEX ix_search_query_log_type ON search_query_log(query_type_code, searched_at);
CREATE INDEX ix_search_query_log_normalized ON search_query_log(normalized_query_text);

CREATE INDEX ix_impression_query ON search_result_impression(search_query_id);
CREATE INDEX ix_impression_restaurant ON search_result_impression(restaurant_id, shown_at);
CREATE INDEX ix_impression_item ON search_result_impression(menu_item_id, shown_at);

CREATE INDEX ix_click_event_user ON click_event(user_id, clicked_at);
CREATE INDEX ix_click_event_guest ON click_event(guest_session_id, clicked_at);
CREATE INDEX ix_click_event_restaurant ON click_event(restaurant_id, click_type_code, clicked_at);
CREATE INDEX ix_click_event_item ON click_event(menu_item_id, clicked_at);
/* ============================================================================
   DATABASE — KhaustanReviews
   Reviews, dish tags, media, replies, moderation, and its own outbox back to KhaustanRestaurantMenu's rating cache. 7 tables.
   ============================================================================ */
SELECT format('CREATE DATABASE %I', 'KhaustanReviews')
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_database
    WHERE datname = 'KhaustanReviews'
)\gexec

\connect "KhaustanReviews"

CREATE TABLE review (
    review_id          BIGINT NOT NULL PRIMARY KEY,
    restaurant_id           BIGINT NOT NULL,     -- soft reference to Restaurant & Menu
    user_id                     BIGINT NOT NULL,  -- soft reference to Identity; reviews require login

    overall_rating                   SMALLINT NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),
    review_text                          TEXT,
    visit_type_code                          VARCHAR(20) CHECK (visit_type_code IS NULL OR visit_type_code IN ('dine_in','takeaway','delivery')),

    status_code                                  VARCHAR(30) NOT NULL DEFAULT 'published'
                                                  CHECK (status_code IN ('published','pending_moderation','removed','flagged')),

    created_at                                       TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    updated_at                                           TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC')
);

-- "Dish-tagged reviews" was an explicit, named feature — a review can call
-- out specific dishes, each optionally with its own rating distinct from
-- the review's overall_rating.
CREATE TABLE review_dish_tag (
    review_id         BIGINT NOT NULL,
    menu_item_id           BIGINT NOT NULL,      -- soft reference to Restaurant & Menu
    dish_rating                 SMALLINT CHECK (dish_rating IS NULL OR dish_rating BETWEEN 1 AND 5),
    PRIMARY KEY (review_id, menu_item_id),
    CONSTRAINT fk_review_dish_tag_review FOREIGN KEY (review_id) REFERENCES review(review_id)
);

-- This service's own media table — it cannot reuse Restaurant & Menu's
-- media_asset because that table lives in a different database.
CREATE TABLE review_media (
    review_media_id     BIGINT NOT NULL PRIMARY KEY,
    review_id                BIGINT NOT NULL,
    storage_uri                   VARCHAR(1000) NOT NULL,
    display_sequence                  INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_review_media_review FOREIGN KEY (review_id) REFERENCES review(review_id)
);

CREATE TABLE review_reply (
    reply_id           BIGINT NOT NULL PRIMARY KEY,
    review_id               BIGINT NOT NULL,
    replier_type_code           VARCHAR(30) NOT NULL CHECK (replier_type_code IN ('restaurant_owner','platform_admin')),
    replier_external_id             VARCHAR(100) NOT NULL,   -- opaque id from Identity/staff-RBAC; not a local FK
    reply_text                          TEXT NOT NULL,
    created_at                              TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_review_reply_review FOREIGN KEY (review_id) REFERENCES review(review_id)
);

CREATE TABLE review_helpful_vote (
    review_id          BIGINT NOT NULL,
    user_id                 BIGINT NOT NULL,     -- soft reference to Identity
    is_helpful                   BOOLEAN NOT NULL,
    voted_at                         TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    PRIMARY KEY (review_id, user_id),
    CONSTRAINT fk_review_helpful_vote_review FOREIGN KEY (review_id) REFERENCES review(review_id)
);

CREATE TABLE review_moderation_action (
    moderation_action_id   BIGINT NOT NULL PRIMARY KEY,
    review_id                   BIGINT NOT NULL,
    action_code                      VARCHAR(30) NOT NULL CHECK (action_code IN ('flagged','removed','restored','warning_issued')),
    actor_external_id                    VARCHAR(100) NOT NULL,   -- opaque id from the admin/staff RBAC domain
    reason                                    VARCHAR(500),
    created_at                                    TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    CONSTRAINT fk_review_moderation_action_review FOREIGN KEY (review_id) REFERENCES review(review_id)
);

-- Same transactional-outbox pattern as Restaurant & Menu's
-- change_event_outbox — a review insert/update/moderation commits together
-- with an outbox row in the same local transaction; a separate publisher
-- forwards it to the event bus. Restaurant & Menu's rating_average/
-- rating_count columns are updated by consuming THIS stream, not by a
-- direct write from this service into that database.
CREATE TABLE review_change_outbox (
    event_id           BIGINT NOT NULL PRIMARY KEY,
    review_id               BIGINT NOT NULL,
    restaurant_id                BIGINT NOT NULL,
    event_type                       VARCHAR(30) NOT NULL CHECK (event_type IN ('review_created','review_updated','review_removed')),
    occurred_at                          TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'UTC'),
    payload                                  TEXT NOT NULL,
    publish_status_code                          VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (publish_status_code IN ('pending','published','failed')),
    published_at                                     TIMESTAMP(3) WITHOUT TIME ZONE
);

CREATE INDEX ix_review_restaurant ON review(restaurant_id, status_code);
CREATE INDEX ix_review_user ON review(user_id);
CREATE INDEX ix_review_dish_tag_item ON review_dish_tag(menu_item_id);
CREATE INDEX ix_review_reply_review ON review_reply(review_id);
CREATE INDEX ix_review_moderation_review ON review_moderation_action(review_id, created_at);
CREATE INDEX ix_review_change_outbox_publish ON review_change_outbox(publish_status_code);
CREATE INDEX ix_review_change_outbox_restaurant ON review_change_outbox(restaurant_id);
