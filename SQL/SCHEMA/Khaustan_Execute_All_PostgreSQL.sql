-- Khaustan PostgreSQL deployment driver
-- Run this file from psql. Keep this file in the same folder as the four SQL scripts.
-- Example:
--   psql -d postgres -f Khaustan_Execute_All_PostgreSQL.sql

\set ON_ERROR_STOP on

\echo '============================================================'
\echo 'Khaustan PostgreSQL deployment started'
\echo '============================================================'

-- Start from the PostgreSQL master/maintenance database.
\connect postgres
--\ir DELETE_ALL.sql
\echo '------------------------------------------------------------'
\echo '1/4 Creating database: KhaustanRestaurantMenu'
\echo '------------------------------------------------------------'
\ir khaustan-KhaustanRestaurantMenu-Create_DB-postgresql.sql

\echo '------------------------------------------------------------'
\echo '2/4 Creating database: KhaustanIdentity'
\echo '------------------------------------------------------------'
\ir khaustan-Identity-Behaviour-Reviews-platform-postgresql.sql

\echo '------------------------------------------------------------'
\echo '3/4 Seeding lookup data: KhaustanRestaurantMenu'
\echo '------------------------------------------------------------'
\connect KhaustanRestaurantMenu
\ir khaustan_lookup_data_seed_KhaustanRestaurantMenu.sql

\echo '------------------------------------------------------------'
\echo '4/4 Seeding lookup data: KhaustanIdentity'
\echo '------------------------------------------------------------'
\connect KhaustanIdentity
\ir khaustan_lookup_data_seed_KhaustanIdentity.sql

\echo '============================================================'
\echo 'Khaustan PostgreSQL deployment completed successfully.'
\echo '============================================================'
