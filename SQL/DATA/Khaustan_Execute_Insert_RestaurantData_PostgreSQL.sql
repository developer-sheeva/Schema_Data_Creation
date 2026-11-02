-- Khaustan PostgreSQL deployment driver
-- Run this file from psql. Keep this file in the same folder as the four SQL scripts.
-- Example:
--   psql -d postgres -f Khaustan_Execute_All_PostgreSQL.sql

\set ON_ERROR_STOP on

\connect KhaustanRestaurantMenu

--400014 Dadar East
--shubham placeholder

--400018 Worli
\ir 400018~001-MBsKitchen.sql

--400066 Borivali East
\ir 400066~001-greens_veg_restaurant_insert.sql
\ir 400066~002-Jumboking-Franchise-insert.sql

--400069 Andheri West
\ir 400069~001-bharat-restaurant-insert.sql
\ir 400069~002-prasadam-pure-veg-insert.sql

--400070 Kurla West
\echo 'Sadanand, sahara, istanbul, sahil, udupi, smokery, utsav'
\ir 400070~001-hotel-sadanand-insert.sql 
\ir 400070~002-Sahara-Hotel-insert.sql
\ir 400070~003-istanbul-darbar-insert.sql 
\ir 400070~004-cafe-sahil-insert.sql
\ir 400070~005-hotel-udupi-sagar-insert.sql 
\ir 400070~006-smokery-insert.sql
\ir 400070~007-rangoon-zaika-insert.sql  
\ir 400070~008-janata-tawa-grill-insert.sql  
\ir 400070~009-janata-fast-food-insert.sql  
\ir 400070~010-Utsav-Bar-Restaurant-insert.sql
\ir 400070~011-mughal-dhaba-insert.sql 
\ir 400070~012-Hotel-Sunlight-insert.sql
\ir 400070~017-hotel-nasheman-family-restaurant-insert.sql
\ir 400070~018-arabian-dastarkhwan-family-restaurant-insert.sql
\ir 400070~019-new-lucky-restaurant-insert.sql

--400081 Mulund East
\echo 'campus, kampa, Parijat, prashant'
\ir 400081~001-campus_veg_treat_insert.sql
\ir 400081~002-kampa_chinese_treat_insert.sql
\ir 400081~003-hotel_parijat_insert.sql
\ir 400081~004-hotel-prashant-insert.sql
\ir 400081~005-vihar-refreshments-pure-veg-insert.sql
\ir 400081~006-manis-cafe-insert.sql
\ir 400081~007-hotel-malvan-swad-insert.sql

--400086 Vidyavihar west
\echo 'hanuman'
\ir 400086~001-hanuman-veg-treat-insert.sql
\ir 400086~002-TheFoodTown-insert.sql
\ir 400086~003-rohini-insert.sql
\ir 400086~004-u2m-insert.sql

--400092 Boriwali West
\ir 400092~001-Jumboking-Franchise-insert.sql
\ir 400092~002-Jumboking-Franchise-insert.sql

--400101 Kandivali East
\ir 400101~001-Jumboking-Franchise-insert.sql
\ir 400101~002-Jumboking-Franchise-insert.sql

-- Thane east
\ir 400603~001-Maitri-Restaurant-insert.sql

--vashi
\ir 400703~001-vishwa-lunch-home-insert.sql
\ir 400703~002-paajis-fast-food_insert.sql
\ir 400703~003-gowdru-dosa-corner-insert.sql
\ir 400703~004-pav-bhaji-center-insert.sql

--Airoli
\ir 400708~001-KrishnaBhog-insert.sql
\ir 400708~002-momo-kitchen-insert.sql

--vasai
\echo 'dhuri-food-plaza'
\ir 401202~001-dhuri-food-plaza-insert.sql

--kudal
\ir 416520~001-hotel-killedar-insert.sql

\echo '============================================================'
\echo 'Khaustan insert completed successfully.'
\echo '============================================================'
