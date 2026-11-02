-- WARNING: This permanently deletes the databases and all their data.

-- 1. Drop KhaustanRestaurantMenu
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'KhaustanRestaurantMenu' AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS "KhaustanRestaurantMenu";

-- 2. Drop KhaustanIdentity
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'KhaustanIdentity'  AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS "KhaustanIdentity";

-- 3. Drop KhaustanSearchBehavior
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'KhaustanSearchBehavior' AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS "KhaustanSearchBehavior";

-- 4. Drop KhaustanReviews
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'KhaustanReviews' AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS "KhaustanReviews";
