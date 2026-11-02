-- =====================================================================
-- Khaustan_Execute_Initial_PostgreSQL.sql
-- Save in : D:/SheEva/Khaustan.com/database/PostGressSQL
--
-- Runs, in ONE psql session and in this order:
--   Step 1  SCHEMA/Khaustan_Execute_All_PostgreSQL.sql
--           creates the four Khaustan databases
--   Step 2  DONE/Khaustan_Execute_Insert_RestaurantData_PostgreSQL.sql
--           loads the restaurant and menu data (20+ scripts)
--
-- HOW TO RUN (as postgres, or any role that may CREATE DATABASE)
--   From the psql prompt, connected to the postgres database:
--     \i 'D:/SheEva/Khaustan.com/database/PostGressSQL/Khaustan_Execute_Initial_PostgreSQL.sql'
--   From a Windows command prompt (add  > run.log 2>&1  to keep a log):
--     psql -U postgres -d postgres -f "D:/SheEva/Khaustan.com/database/PostGressSQL/Khaustan_Execute_Initial_PostgreSQL.sql"
--
-- PATHS use forward slashes on purpose: inside a quoted psql argument a
-- backslash is an escape character, so a path written with backslashes
-- would be mangled.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Session settings (they stay in effect for every script called below,
-- and for the rest of your psql session)
--   ECHO none, QUIET on   no echo of the inner scripts' commands, and no
--                         command tags ("INSERT 0 1", "CREATE TABLE", ...)
--                         or "You are now connected" lines. Errors, warnings
--                         and NOTICE messages are still shown.
--   ON_ERROR_STOP on      stop at the FIRST error, so a failed step 1 can
--                         never be followed by step 2. The "Finished" line at
--                         the end therefore only appears if everything worked.
--                         Change to off to carry on past errors.
--   AUTOCOMMIT on         CREATE DATABASE cannot run inside a transaction.
--   pager off, timing off nothing may wait for a key press or print timings.
-- ---------------------------------------------------------------------
\set ON_ERROR_STOP on
\set AUTOCOMMIT on
\set ECHO none
\set ECHO_HIDDEN off
\set QUIET on
\pset pager off
\timing off

\echo
\echo ======================================================================
\echo  KHAUSTAN - database build and data load
\echo ======================================================================

-- ---------------------------------------------------------------------
-- Step 0  Clean start
-- Reconnect to the postgres maintenance database. This
--   * closes any connection this session still holds on one of the four
--     Khaustan databases (a database cannot be dropped while it is open),
--   * throws away any transaction left half-open by an earlier failed run.
-- ---------------------------------------------------------------------
\connect postgres

-- OPTIONAL - uncomment if step 1 stops with "database ... is being accessed
-- by other users" (pgAdmin, DBeaver or another psql window is connected):
-- SELECT count(pg_terminate_backend(pid)) AS sessions_closed
--   FROM pg_stat_activity
--  WHERE datname ILIKE 'khaustan%' AND pid <> pg_backend_pid();

-- ---------------------------------------------------------------------
-- Step 1  Create the four databases
-- ---------------------------------------------------------------------
SELECT to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS') AS kh_now \gset
\echo [1/2] Creating the four databases - started :kh_now
\set ECHO none
\set QUIET on
\ir 'SCHEMA/Khaustan_Execute_All_PostgreSQL.sql'

-- ---------------------------------------------------------------------
-- Between the steps
-- Step 1 leaves the session connected to whichever database it created
-- last. Reconnect to KhaustanRestaurantMenu, the database the restaurant
-- scripts load into, so step 2 starts from a known state (scripts that do
-- their own \connect are not affected).
-- ---------------------------------------------------------------------
\connect "KhaustanRestaurantMenu"

-- ---------------------------------------------------------------------
-- Step 2  Load the restaurant and menu data
-- ---------------------------------------------------------------------
SELECT to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS') AS kh_now \gset
\echo [2/2] Loading restaurant and menu data - started :kh_now
\set ECHO none
\set QUIET on
\ir 'DATA/Khaustan_Execute_Insert_RestaurantData_PostgreSQL.sql'

-- ---------------------------------------------------------------------
-- Finish: leave the session on the postgres database, holding no
-- connection to any Khaustan database, so this script can be run again.
-- ---------------------------------------------------------------------
\connect postgres
SELECT to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS') AS kh_now \gset
\echo
\echo Finished :kh_now - both steps completed.
\echo
