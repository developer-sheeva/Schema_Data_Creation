
/*
===============================================================================
KHAUSTAN.COM
Restaurant & Menu Service
SQL Server 2019+ logical schema / DDL

Design principles
- This database is owned by the Restaurant & Menu microservice.
- BIGINT application-generated identifiers are used; no IDENTITY is assumed.
- No user accounts, RBAC, reviews, orders, payments, search behavior,
  clickstream, delivery execution/tracking, or LLM-training archive is stored.
- JSON payloads for the bounded outbox are stored as NVARCHAR(MAX) for
  portability at the logical-model level.
===============================================================================
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE master;
GO

-- Drop database if it already exists (Use with caution in production!)
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = N'KhaustanDB1')
BEGIN
    ALTER DATABASE KhaustanDB1 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE KhaustanDB1;
END
GO

-- Create the database with professional configurations
CREATE DATABASE KhaustanDB1
ON PRIMARY 
(
    NAME = N'KhaustanDB1_Data',
    FILENAME = N'D:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\KhaustanDB1_Data.mdf',
    SIZE = 100MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = 50MB
)
LOG ON 
(
    NAME = N'KhaustanDB1_Log',
    FILENAME = N'D:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\KhaustanDB1_Log.ldf',
    SIZE = 50MB,
    MAXSIZE = 2GB,
    FILEGROWTH = 20MB
);
GO

-- Configure advanced database options
ALTER DATABASE KhaustanDB1 SET RECOVERY FULL;
GO
ALTER DATABASE KhaustanDB1 SET ANSI_NULL_DEFAULT ON;
GO
ALTER DATABASE KhaustanDB1 SET ANSI_NULLS ON;
GO
ALTER DATABASE KhaustanDB1 SET ANSI_PADDING ON;
GO
ALTER DATABASE KhaustanDB1 SET ANSI_WARNINGS ON;
GO
ALTER DATABASE KhaustanDB1 SET ARITHABORT ON;
GO
ALTER DATABASE KhaustanDB1 SET QUOTED_IDENTIFIER ON;
GO

use KhaustanDB1 ;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'restaurant_menu')
    EXEC(N'CREATE SCHEMA restaurant_menu');
GO

/* ============================================================================
   1. Establishment, brand and restaurant
   ============================================================================ */

CREATE TABLE restaurant_menu.brand (
    brand_id BIGINT NOT NULL,
    name NVARCHAR(200) NOT NULL,
    normalized_name NVARCHAR(200) NOT NULL,
    legal_name NVARCHAR(250) NULL,
    description NVARCHAR(1000) NULL,
    website_url NVARCHAR(500) NULL,
    status_code VARCHAR(30) NOT NULL,
    created_at DATETIME2(3) NOT NULL,
    updated_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_brand PRIMARY KEY (brand_id)
);
GO

CREATE TABLE restaurant_menu.establishment (
    establishment_id BIGINT NOT NULL,
    name NVARCHAR(250) NOT NULL,
    normalized_name NVARCHAR(250) NOT NULL,
    address_line1 NVARCHAR(300) NULL,
    address_line2 NVARCHAR(300) NULL,
    locality NVARCHAR(150) NULL,
    city NVARCHAR(100) NULL,
    state NVARCHAR(100) NULL,
    country_code CHAR(2) NOT NULL,
    postal_code VARCHAR(15) NULL,
    latitude DECIMAL(9,6) NULL,
    longitude DECIMAL(9,6) NULL,
    status_code VARCHAR(30) NOT NULL,
    created_at DATETIME2(3) NOT NULL,
    updated_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_establishment PRIMARY KEY (establishment_id)
);
GO

CREATE TABLE restaurant_menu.restaurant (
    restaurant_id BIGINT NOT NULL,
    establishment_id BIGINT NOT NULL,
    brand_id BIGINT NULL,
    display_name NVARCHAR(250) NOT NULL,
    normalized_name NVARCHAR(250) NOT NULL,
    description NVARCHAR(2000) NULL,
    listing_tier_code VARCHAR(30) NULL,
    status_code VARCHAR(30) NOT NULL,
    is_24_hours BIT NOT NULL,
    is_temporarily_closed BIT NOT NULL,
    is_permanently_closed BIT NOT NULL,
    rating_average DECIMAL(3,2) NULL,
    rating_count INT NULL,
    cost_for_two_amount DECIMAL(12,2) NULL,
    cost_for_two_currency CHAR(3) NULL,
    last_verified_at DATETIME2(3) NULL,
    verification_status_code VARCHAR(30) NULL,
    created_at DATETIME2(3) NOT NULL,
    updated_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_restaurant PRIMARY KEY (restaurant_id),
    CONSTRAINT FK_restaurant_establishment FOREIGN KEY (establishment_id)
        REFERENCES restaurant_menu.establishment(establishment_id),
    CONSTRAINT FK_restaurant_brand FOREIGN KEY (brand_id)
        REFERENCES restaurant_menu.brand(brand_id),
    CONSTRAINT CK_restaurant_rating CHECK (rating_average IS NULL OR (rating_average >= 0 AND rating_average <= 5)),
    CONSTRAINT CK_restaurant_rating_count CHECK (rating_count IS NULL OR rating_count >= 0)
);
GO

CREATE TABLE restaurant_menu.restaurant_external_identity (
    identity_id BIGINT NOT NULL,
    restaurant_id BIGINT NOT NULL,
    source_system_code VARCHAR(50) NOT NULL,
    external_restaurant_id NVARCHAR(200) NOT NULL,
    created_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_restaurant_external_identity PRIMARY KEY (identity_id),
    CONSTRAINT FK_restaurant_external_identity_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurant_menu.restaurant(restaurant_id),
    CONSTRAINT UQ_restaurant_external_identity UNIQUE (source_system_code, external_restaurant_id)
);
GO

/* ============================================================================
   2. Extensible restaurant taxonomy / filters
   ============================================================================ */

CREATE TABLE restaurant_menu.platform_tag (
    tag_id BIGINT NOT NULL,
    tag_code VARCHAR(80) NOT NULL,
    name NVARCHAR(150) NOT NULL,
    tag_scope VARCHAR(30) NOT NULL,
    value_type VARCHAR(20) NOT NULL,
    is_multivalue BIT NOT NULL,
    is_active BIT NOT NULL,
    CONSTRAINT PK_platform_tag PRIMARY KEY (tag_id),
    CONSTRAINT UQ_platform_tag_code UNIQUE (tag_code)
);
GO

CREATE TABLE restaurant_menu.restaurant_tag (
    restaurant_tag_id BIGINT NOT NULL,
    restaurant_id BIGINT NOT NULL,
    tag_id BIGINT NOT NULL,
    value_text NVARCHAR(250) NULL,
    value_number DECIMAL(18,4) NULL,
    value_boolean BIT NULL,
    created_at DATETIME2(3) NOT NULL,
    updated_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_restaurant_tag PRIMARY KEY (restaurant_tag_id),
    CONSTRAINT FK_restaurant_tag_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurant_menu.restaurant(restaurant_id),
    CONSTRAINT FK_restaurant_tag_platform_tag FOREIGN KEY (tag_id)
        REFERENCES restaurant_menu.platform_tag(tag_id),
    CONSTRAINT UQ_restaurant_tag_value UNIQUE (restaurant_id, tag_id, value_text)
);
GO

/* ============================================================================
   3. Service modes and operating hours
   ============================================================================ */

CREATE TABLE restaurant_menu.service_mode (
    service_mode_id BIGINT NOT NULL,
    code VARCHAR(40) NOT NULL,
    name NVARCHAR(100) NOT NULL,
    is_active BIT NOT NULL,
    CONSTRAINT PK_service_mode PRIMARY KEY (service_mode_id),
    CONSTRAINT UQ_service_mode_code UNIQUE (code)
);
GO

CREATE TABLE restaurant_menu.restaurant_service_mode (
    restaurant_id BIGINT NOT NULL,
    service_mode_id BIGINT NOT NULL,
    is_active BIT NOT NULL,
    notes NVARCHAR(500) NULL,
    CONSTRAINT PK_restaurant_service_mode PRIMARY KEY (restaurant_id, service_mode_id),
    CONSTRAINT FK_restaurant_service_mode_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurant_menu.restaurant(restaurant_id),
    CONSTRAINT FK_restaurant_service_mode_service_mode FOREIGN KEY (service_mode_id)
        REFERENCES restaurant_menu.service_mode(service_mode_id)
);
GO

CREATE TABLE restaurant_menu.restaurant_hours (
    restaurant_hours_id BIGINT NOT NULL,
    restaurant_id BIGINT NOT NULL,
    day_of_week SMALLINT NOT NULL,
    slot_sequence SMALLINT NOT NULL,
    opens_at TIME(0) NOT NULL,
    closes_at TIME(0) NOT NULL,
    CONSTRAINT PK_restaurant_hours PRIMARY KEY (restaurant_hours_id),
    CONSTRAINT FK_restaurant_hours_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurant_menu.restaurant(restaurant_id),
    CONSTRAINT UQ_restaurant_hours_slot UNIQUE (restaurant_id, day_of_week, slot_sequence),
    CONSTRAINT CK_restaurant_hours_day CHECK (day_of_week BETWEEN 1 AND 7)
);
GO

CREATE TABLE restaurant_menu.restaurant_holiday_hours (
    holiday_hours_id BIGINT NOT NULL,
    restaurant_id BIGINT NOT NULL,
    holiday_date DATE NOT NULL,
    is_closed BIT NOT NULL,
    opens_at TIME(0) NULL,
    closes_at TIME(0) NULL,
    notes NVARCHAR(300) NULL,
    CONSTRAINT PK_restaurant_holiday_hours PRIMARY KEY (holiday_hours_id),
    CONSTRAINT FK_restaurant_holiday_hours_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurant_menu.restaurant(restaurant_id),
    CONSTRAINT UQ_restaurant_holiday_hours UNIQUE (restaurant_id, holiday_date)
);
GO

/* ============================================================================
   4. Brand master menus / chain inheritance
   ============================================================================ */

CREATE TABLE restaurant_menu.brand_menu_template (
    template_id BIGINT NOT NULL,
    brand_id BIGINT NOT NULL,
    name NVARCHAR(200) NOT NULL,
    version_no INT NOT NULL,
    is_active BIT NOT NULL,
    created_at DATETIME2(3) NOT NULL,
    updated_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_brand_menu_template PRIMARY KEY (template_id),
    CONSTRAINT FK_brand_menu_template_brand FOREIGN KEY (brand_id)
        REFERENCES restaurant_menu.brand(brand_id),
    CONSTRAINT UQ_brand_menu_template_version UNIQUE (brand_id, version_no)
);
GO

CREATE TABLE restaurant_menu.brand_menu_template_board (
    template_board_id BIGINT NOT NULL,
    template_id BIGINT NOT NULL,
    name NVARCHAR(200) NOT NULL,
    board_type_code VARCHAR(40) NOT NULL,
    description NVARCHAR(1000) NULL,
    display_sequence INT NOT NULL,
    is_active BIT NOT NULL,
    CONSTRAINT PK_brand_menu_template_board PRIMARY KEY (template_board_id),
    CONSTRAINT FK_brand_menu_template_board_template FOREIGN KEY (template_id)
        REFERENCES restaurant_menu.brand_menu_template(template_id)
);
GO

/* ============================================================================
   5. Canonical dish
   ============================================================================ */

CREATE TABLE restaurant_menu.canonical_dish (
    canonical_dish_id BIGINT NOT NULL,
    canonical_name NVARCHAR(250) NOT NULL,
    normalized_name NVARCHAR(250) NOT NULL,
    description NVARCHAR(2000) NULL,
    food_classification_code VARCHAR(30) NULL,
    is_jain BIT NOT NULL,
    is_vegan BIT NOT NULL,
    is_eggless BIT NOT NULL,
    is_gluten_free BIT NOT NULL,
    is_halal BIT NOT NULL,
    is_onion_garlic_free BIT NOT NULL,
    contains_nuts BIT NOT NULL,
    created_at DATETIME2(3) NOT NULL,
    updated_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_canonical_dish PRIMARY KEY (canonical_dish_id)
);
GO

CREATE TABLE restaurant_menu.canonical_dish_name (
    canonical_dish_name_id BIGINT NOT NULL,
    canonical_dish_id BIGINT NOT NULL,
    language_code VARCHAR(20) NOT NULL,
    name NVARCHAR(250) NOT NULL,
    normalized_name NVARCHAR(250) NOT NULL,
    name_type_code VARCHAR(30) NOT NULL,
    CONSTRAINT PK_canonical_dish_name PRIMARY KEY (canonical_dish_name_id),
    CONSTRAINT FK_canonical_dish_name_dish FOREIGN KEY (canonical_dish_id)
        REFERENCES restaurant_menu.canonical_dish(canonical_dish_id),
    CONSTRAINT UQ_canonical_dish_name UNIQUE (canonical_dish_id, language_code, name_type_code)
);
GO

/* ============================================================================
   6. Brand template item
   ============================================================================ */

CREATE TABLE restaurant_menu.brand_menu_template_item (
    template_item_id BIGINT NOT NULL,
    template_id BIGINT NOT NULL,
    canonical_dish_id BIGINT NULL,
    name NVARCHAR(250) NOT NULL,
    description NVARCHAR(2000) NULL,
    food_classification_code VARCHAR(30) NULL,
    is_jain BIT NOT NULL,
    is_vegan BIT NOT NULL,
    is_eggless BIT NOT NULL,
    is_gluten_free BIT NOT NULL,
    is_halal BIT NOT NULL,
    is_onion_garlic_free BIT NOT NULL,
    contains_nuts BIT NOT NULL,
    status_code VARCHAR(30) NOT NULL,
    created_at DATETIME2(3) NOT NULL,
    updated_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_brand_menu_template_item PRIMARY KEY (template_item_id),
    CONSTRAINT FK_brand_menu_template_item_template FOREIGN KEY (template_id)
        REFERENCES restaurant_menu.brand_menu_template(template_id),
    CONSTRAINT FK_brand_menu_template_item_dish FOREIGN KEY (canonical_dish_id)
        REFERENCES restaurant_menu.canonical_dish(canonical_dish_id)
);
GO

/* ============================================================================
   7. Menu boards / buffet instances / restaurant category tree
   ============================================================================ */

CREATE TABLE restaurant_menu.menu_board (
    menu_board_id BIGINT NOT NULL,
    restaurant_id BIGINT NOT NULL,
    template_board_id BIGINT NULL,
    name NVARCHAR(200) NOT NULL,
    board_type_code VARCHAR(40) NOT NULL,
    description NVARCHAR(1000) NULL,
    valid_from DATE NULL,
    valid_to DATE NULL,
    is_active BIT NOT NULL,
    display_sequence INT NOT NULL,
    created_at DATETIME2(3) NOT NULL,
    updated_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_menu_board PRIMARY KEY (menu_board_id),
    CONSTRAINT FK_menu_board_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurant_menu.restaurant(restaurant_id),
    CONSTRAINT FK_menu_board_template_board FOREIGN KEY (template_board_id)
        REFERENCES restaurant_menu.brand_menu_template_board(template_board_id)
);
GO

CREATE TABLE restaurant_menu.menu_board_instance (
    board_instance_id BIGINT NOT NULL,
    menu_board_id BIGINT NOT NULL,
    instance_date DATE NOT NULL,
    start_time TIME(0) NULL,
    end_time TIME(0) NULL,
    price_per_person DECIMAL(12,2) NULL,
    is_active BIT NOT NULL,
    notes NVARCHAR(500) NULL,
    CONSTRAINT PK_menu_board_instance PRIMARY KEY (board_instance_id),
    CONSTRAINT FK_menu_board_instance_board FOREIGN KEY (menu_board_id)
        REFERENCES restaurant_menu.menu_board(menu_board_id),
    CONSTRAINT UQ_menu_board_instance UNIQUE (menu_board_id, instance_date, start_time)
);
GO

CREATE TABLE restaurant_menu.menu_category (
    menu_category_id BIGINT NOT NULL,
    restaurant_id BIGINT NOT NULL,
    parent_category_id BIGINT NULL,
    name NVARCHAR(200) NOT NULL,
    description NVARCHAR(500) NULL,
    image_url NVARCHAR(1000) NULL,
    display_sequence INT NOT NULL,
    is_active BIT NOT NULL,
    CONSTRAINT PK_menu_category PRIMARY KEY (menu_category_id),
    CONSTRAINT FK_menu_category_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurant_menu.restaurant(restaurant_id),
    CONSTRAINT FK_menu_category_parent FOREIGN KEY (parent_category_id)
        REFERENCES restaurant_menu.menu_category(menu_category_id)
);
GO

CREATE TABLE restaurant_menu.menu_board_category (
    menu_board_id BIGINT NOT NULL,
    menu_category_id BIGINT NOT NULL,
    display_sequence INT NOT NULL,
    CONSTRAINT PK_menu_board_category PRIMARY KEY (menu_board_id, menu_category_id),
    CONSTRAINT FK_menu_board_category_board FOREIGN KEY (menu_board_id)
        REFERENCES restaurant_menu.menu_board(menu_board_id),
    CONSTRAINT FK_menu_board_category_category FOREIGN KEY (menu_category_id)
        REFERENCES restaurant_menu.menu_category(menu_category_id)
);
GO

/* ============================================================================
   8. Restaurant menu item
   ============================================================================ */

CREATE TABLE restaurant_menu.menu_item (
    menu_item_id BIGINT NOT NULL,
    restaurant_id BIGINT NOT NULL,
    canonical_dish_id BIGINT NULL,
    template_item_id BIGINT NULL,
    name NVARCHAR(250) NOT NULL,
    normalized_name NVARCHAR(250) NOT NULL,
    description NVARCHAR(2000) NULL,
    food_classification_code VARCHAR(30) NULL,
    is_jain BIT NOT NULL,
    is_vegan BIT NOT NULL,
    is_eggless BIT NOT NULL,
    is_gluten_free BIT NOT NULL,
    is_halal BIT NOT NULL,
    is_onion_garlic_free BIT NOT NULL,
    contains_nuts BIT NOT NULL,
    is_bestseller BIT NOT NULL,
    is_recommended BIT NOT NULL,
    status_code VARCHAR(30) NOT NULL,
    inheritance_mode_code VARCHAR(30) NULL,
    last_verified_at DATETIME2(3) NULL,
    verification_status_code VARCHAR(30) NULL,
    created_at DATETIME2(3) NOT NULL,
    updated_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_menu_item PRIMARY KEY (menu_item_id),
    CONSTRAINT FK_menu_item_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurant_menu.restaurant(restaurant_id),
    CONSTRAINT FK_menu_item_canonical_dish FOREIGN KEY (canonical_dish_id)
        REFERENCES restaurant_menu.canonical_dish(canonical_dish_id),
    CONSTRAINT FK_menu_item_template_item FOREIGN KEY (template_item_id)
        REFERENCES restaurant_menu.brand_menu_template_item(template_item_id)
);
GO

CREATE TABLE restaurant_menu.menu_item_name (
    menu_item_name_id BIGINT NOT NULL,
    menu_item_id BIGINT NOT NULL,
    language_code VARCHAR(20) NOT NULL,
    name NVARCHAR(250) NOT NULL,
    normalized_name NVARCHAR(250) NOT NULL,
    name_type_code VARCHAR(30) NOT NULL,
    CONSTRAINT PK_menu_item_name PRIMARY KEY (menu_item_name_id),
    CONSTRAINT FK_menu_item_name_item FOREIGN KEY (menu_item_id)
        REFERENCES restaurant_menu.menu_item(menu_item_id),
    CONSTRAINT UQ_menu_item_name UNIQUE (menu_item_id, language_code, name_type_code)
);
GO

CREATE TABLE restaurant_menu.menu_board_item (
    menu_board_item_id BIGINT NOT NULL,
    menu_board_id BIGINT NOT NULL,
    menu_item_id BIGINT NOT NULL,
    menu_category_id BIGINT NULL,
    display_sequence INT NOT NULL,
    is_featured BIT NOT NULL,
    is_bestseller BIT NOT NULL,
    is_recommended BIT NOT NULL,
    valid_from DATE NULL,
    valid_to DATE NULL,
    CONSTRAINT PK_menu_board_item PRIMARY KEY (menu_board_item_id),
    CONSTRAINT FK_menu_board_item_board FOREIGN KEY (menu_board_id)
        REFERENCES restaurant_menu.menu_board(menu_board_id),
    CONSTRAINT FK_menu_board_item_item FOREIGN KEY (menu_item_id)
        REFERENCES restaurant_menu.menu_item(menu_item_id),
    CONSTRAINT FK_menu_board_item_category FOREIGN KEY (menu_category_id)
        REFERENCES restaurant_menu.menu_category(menu_category_id),
    CONSTRAINT UQ_menu_board_item UNIQUE (menu_board_id, menu_item_id)
);
GO

CREATE TABLE restaurant_menu.menu_board_instance_item (
    board_instance_id BIGINT NOT NULL,
    menu_item_id BIGINT NOT NULL,
    display_sequence INT NOT NULL,
    included_flag BIT NOT NULL,
    CONSTRAINT PK_menu_board_instance_item PRIMARY KEY (board_instance_id, menu_item_id),
    CONSTRAINT FK_menu_board_instance_item_instance FOREIGN KEY (board_instance_id)
        REFERENCES restaurant_menu.menu_board_instance(board_instance_id),
    CONSTRAINT FK_menu_board_instance_item_item FOREIGN KEY (menu_item_id)
        REFERENCES restaurant_menu.menu_item(menu_item_id)
);
GO

/* ============================================================================
   9. Variants, pricing schedules, versioned prices and item charges
   ============================================================================ */

CREATE TABLE restaurant_menu.menu_item_variant (
    variant_id BIGINT NOT NULL,
    menu_item_id BIGINT NOT NULL,
    variant_name NVARCHAR(150) NOT NULL,
    variant_code VARCHAR(50) NULL,
    pricing_basis_code VARCHAR(40) NOT NULL,
    quantity_value DECIMAL(12,4) NULL,
    quantity_unit_code VARCHAR(30) NULL,
    serving_size_ml DECIMAL(12,3) NULL,
    display_sequence INT NOT NULL,
    is_default BIT NOT NULL,
    is_active BIT NOT NULL,
    CONSTRAINT PK_menu_item_variant PRIMARY KEY (variant_id),
    CONSTRAINT FK_menu_item_variant_item FOREIGN KEY (menu_item_id)
        REFERENCES restaurant_menu.menu_item(menu_item_id)
);
GO

CREATE TABLE restaurant_menu.price_schedule (
    price_schedule_id BIGINT NOT NULL,
    name NVARCHAR(150) NOT NULL,
    description NVARCHAR(500) NULL,
    start_time TIME(0) NULL,
    end_time TIME(0) NULL,
    is_active BIT NOT NULL,
    CONSTRAINT PK_price_schedule PRIMARY KEY (price_schedule_id)
);
GO

CREATE TABLE restaurant_menu.price_schedule_day (
    price_schedule_id BIGINT NOT NULL,
    day_of_week SMALLINT NOT NULL,
    CONSTRAINT PK_price_schedule_day PRIMARY KEY (price_schedule_id, day_of_week),
    CONSTRAINT FK_price_schedule_day_schedule FOREIGN KEY (price_schedule_id)
        REFERENCES restaurant_menu.price_schedule(price_schedule_id),
    CONSTRAINT CK_price_schedule_day_day CHECK (day_of_week BETWEEN 1 AND 7)
);
GO

CREATE TABLE restaurant_menu.source_record (
    source_id BIGINT NOT NULL,
    source_type_code VARCHAR(40) NOT NULL,
    external_reference NVARCHAR(500) NULL,
    source_uri NVARCHAR(1000) NULL,
    created_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_source_record PRIMARY KEY (source_id)
);
GO

CREATE TABLE restaurant_menu.menu_item_price (
    price_id BIGINT NOT NULL,
    variant_id BIGINT NOT NULL,
    service_mode_id BIGINT NULL,
    price_schedule_id BIGINT NULL,
    price_amount DECIMAL(12,2) NULL,
    currency_code CHAR(3) NOT NULL,
    is_market_price BIT NOT NULL,
    tax_regime_code VARCHAR(40) NULL,
    tax_inclusion_code VARCHAR(30) NULL,
    tax_rate DECIMAL(7,4) NULL,
    effective_from DATETIME2(3) NOT NULL,
    effective_to DATETIME2(3) NULL,
    verification_status_code VARCHAR(30) NULL,
    source_id BIGINT NULL,
    created_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_menu_item_price PRIMARY KEY (price_id),
    CONSTRAINT FK_menu_item_price_variant FOREIGN KEY (variant_id)
        REFERENCES restaurant_menu.menu_item_variant(variant_id),
    CONSTRAINT FK_menu_item_price_service_mode FOREIGN KEY (service_mode_id)
        REFERENCES restaurant_menu.service_mode(service_mode_id),
    CONSTRAINT FK_menu_item_price_schedule FOREIGN KEY (price_schedule_id)
        REFERENCES restaurant_menu.price_schedule(price_schedule_id),
    CONSTRAINT FK_menu_item_price_source FOREIGN KEY (source_id)
        REFERENCES restaurant_menu.source_record(source_id),
    CONSTRAINT CK_menu_item_price_amount CHECK (
        (is_market_price = 1 AND price_amount IS NULL)
        OR
        (is_market_price = 0 AND price_amount IS NOT NULL AND price_amount >= 0)
    ),
    CONSTRAINT CK_menu_item_price_tax_rate CHECK (tax_rate IS NULL OR tax_rate >= 0)
);
GO

CREATE TABLE restaurant_menu.menu_item_charge (
    charge_id BIGINT NOT NULL,
    menu_item_id BIGINT NOT NULL,
    service_mode_id BIGINT NULL,
    charge_type_code VARCHAR(40) NOT NULL,
    calculation_type_code VARCHAR(30) NOT NULL,
    amount DECIMAL(12,2) NULL,
    percentage DECIMAL(7,4) NULL,
    tax_regime_code VARCHAR(40) NULL,
    effective_from DATETIME2(3) NOT NULL,
    effective_to DATETIME2(3) NULL,
    is_active BIT NOT NULL,
    CONSTRAINT PK_menu_item_charge PRIMARY KEY (charge_id),
    CONSTRAINT FK_menu_item_charge_item FOREIGN KEY (menu_item_id)
        REFERENCES restaurant_menu.menu_item(menu_item_id),
    CONSTRAINT FK_menu_item_charge_service_mode FOREIGN KEY (service_mode_id)
        REFERENCES restaurant_menu.service_mode(service_mode_id),
    CONSTRAINT CK_menu_item_charge_value CHECK (
        (calculation_type_code = 'FIXED' AND amount IS NOT NULL AND amount >= 0)
        OR
        (calculation_type_code = 'PERCENTAGE' AND percentage IS NOT NULL AND percentage >= 0)
        OR
        (calculation_type_code NOT IN ('FIXED','PERCENTAGE'))
    )
);
GO

/* ============================================================================
   10. Availability
   ============================================================================ */

CREATE TABLE restaurant_menu.menu_item_availability (
    availability_id BIGINT NOT NULL,
    menu_item_id BIGINT NOT NULL,
    day_of_week SMALLINT NULL,
    start_time TIME(0) NULL,
    end_time TIME(0) NULL,
    effective_from DATE NULL,
    effective_to DATE NULL,
    max_quantity INT NULL,
    is_active BIT NOT NULL,
    CONSTRAINT PK_menu_item_availability PRIMARY KEY (availability_id),
    CONSTRAINT FK_menu_item_availability_item FOREIGN KEY (menu_item_id)
        REFERENCES restaurant_menu.menu_item(menu_item_id),
    CONSTRAINT CK_menu_item_availability_day CHECK (day_of_week IS NULL OR day_of_week BETWEEN 1 AND 7),
    CONSTRAINT CK_menu_item_availability_qty CHECK (max_quantity IS NULL OR max_quantity >= 0)
);
GO

CREATE TABLE restaurant_menu.menu_item_availability_override (
    override_id BIGINT NOT NULL,
    menu_item_id BIGINT NOT NULL,
    override_date DATE NOT NULL,
    start_time TIME(0) NULL,
    end_time TIME(0) NULL,
    status_code VARCHAR(30) NOT NULL,
    quantity_remaining INT NULL,
    reason NVARCHAR(300) NULL,
    CONSTRAINT PK_menu_item_availability_override PRIMARY KEY (override_id),
    CONSTRAINT FK_menu_item_availability_override_item FOREIGN KEY (menu_item_id)
        REFERENCES restaurant_menu.menu_item(menu_item_id),
    CONSTRAINT UQ_menu_item_availability_override UNIQUE (menu_item_id, override_date),
    CONSTRAINT CK_menu_item_availability_override_qty CHECK (
        quantity_remaining IS NULL OR quantity_remaining >= 0
    )
);
GO

/* ============================================================================
   11. Combos / thalis / meal bundles
   ============================================================================ */

CREATE TABLE restaurant_menu.bundle (
    bundle_id BIGINT NOT NULL,
    menu_item_id BIGINT NOT NULL,
    bundle_type_code VARCHAR(30) NOT NULL,
    is_customizable BIT NOT NULL,
    description NVARCHAR(1000) NULL,
    CONSTRAINT PK_bundle PRIMARY KEY (bundle_id),
    CONSTRAINT UQ_bundle_menu_item UNIQUE (menu_item_id),
    CONSTRAINT FK_bundle_menu_item FOREIGN KEY (menu_item_id)
        REFERENCES restaurant_menu.menu_item(menu_item_id)
);
GO

CREATE TABLE restaurant_menu.bundle_group (
    bundle_group_id BIGINT NOT NULL,
    bundle_id BIGINT NOT NULL,
    name NVARCHAR(150) NOT NULL,
    selection_min INT NOT NULL,
    selection_max INT NOT NULL,
    refill_policy_code VARCHAR(30) NULL,
    refill_limit INT NULL,
    display_sequence INT NOT NULL,
    CONSTRAINT PK_bundle_group PRIMARY KEY (bundle_group_id),
    CONSTRAINT FK_bundle_group_bundle FOREIGN KEY (bundle_id)
        REFERENCES restaurant_menu.bundle(bundle_id),
    CONSTRAINT CK_bundle_group_selection CHECK (
        selection_min >= 0 AND selection_max >= selection_min
    ),
    CONSTRAINT CK_bundle_group_refill CHECK (
        refill_limit IS NULL OR refill_limit >= 0
    )
);
GO

CREATE TABLE restaurant_menu.bundle_component (
    bundle_component_id BIGINT NOT NULL,
    bundle_id BIGINT NOT NULL,
    bundle_group_id BIGINT NULL,
    component_menu_item_id BIGINT NOT NULL,
    quantity DECIMAL(12,3) NOT NULL,
    display_sequence INT NOT NULL,
    is_default BIT NOT NULL,
    CONSTRAINT PK_bundle_component PRIMARY KEY (bundle_component_id),
    CONSTRAINT FK_bundle_component_bundle FOREIGN KEY (bundle_id)
        REFERENCES restaurant_menu.bundle(bundle_id),
    CONSTRAINT FK_bundle_component_group FOREIGN KEY (bundle_group_id)
        REFERENCES restaurant_menu.bundle_group(bundle_group_id),
    CONSTRAINT FK_bundle_component_item FOREIGN KEY (component_menu_item_id)
        REFERENCES restaurant_menu.menu_item(menu_item_id),
    CONSTRAINT CK_bundle_component_quantity CHECK (quantity > 0)
);
GO

/* ============================================================================
   12. Bar extension
   ============================================================================ */

CREATE TABLE restaurant_menu.bar_product (
    bar_product_id BIGINT NOT NULL,
    product_type_code VARCHAR(40) NOT NULL,
    brand_name NVARCHAR(200) NULL,
    product_name NVARCHAR(250) NOT NULL,
    origin_code VARCHAR(40) NULL,
    abv_percent DECIMAL(6,3) NULL,
    spirit_type_code VARCHAR(40) NULL,
    is_imported BIT NOT NULL,
    created_at DATETIME2(3) NOT NULL,
    updated_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_bar_product PRIMARY KEY (bar_product_id),
    CONSTRAINT CK_bar_product_abv CHECK (abv_percent IS NULL OR (abv_percent >= 0 AND abv_percent <= 100))
);
GO

CREATE TABLE restaurant_menu.bar_menu_item (
    menu_item_id BIGINT NOT NULL,
    bar_product_id BIGINT NULL,
    bar_item_type_code VARCHAR(40) NOT NULL,
    cocktail_base_required BIT NOT NULL,
    notes NVARCHAR(1000) NULL,
    CONSTRAINT PK_bar_menu_item PRIMARY KEY (menu_item_id),
    CONSTRAINT FK_bar_menu_item_item FOREIGN KEY (menu_item_id)
        REFERENCES restaurant_menu.menu_item(menu_item_id),
    CONSTRAINT FK_bar_menu_item_product FOREIGN KEY (bar_product_id)
        REFERENCES restaurant_menu.bar_product(bar_product_id)
);
GO

CREATE TABLE restaurant_menu.cocktail_base_option (
    cocktail_base_option_id BIGINT NOT NULL,
    cocktail_menu_item_id BIGINT NOT NULL,
    bar_product_id BIGINT NOT NULL,
    additional_price DECIMAL(12,2) NULL,
    is_default BIT NOT NULL,
    CONSTRAINT PK_cocktail_base_option PRIMARY KEY (cocktail_base_option_id),
    CONSTRAINT FK_cocktail_base_option_menu_item FOREIGN KEY (cocktail_menu_item_id)
        REFERENCES restaurant_menu.bar_menu_item(menu_item_id),
    CONSTRAINT FK_cocktail_base_option_product FOREIGN KEY (bar_product_id)
        REFERENCES restaurant_menu.bar_product(bar_product_id),
    CONSTRAINT CK_cocktail_base_option_price CHECK (
        additional_price IS NULL OR additional_price >= 0
    )
);
GO

/* ============================================================================
   13. Media
   ============================================================================ */

CREATE TABLE restaurant_menu.media_asset (
    media_asset_id BIGINT NOT NULL,
    storage_uri NVARCHAR(1000) NOT NULL,
    media_type_code VARCHAR(30) NOT NULL,
    width INT NULL,
    height INT NULL,
    checksum VARCHAR(128) NULL,
    created_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_media_asset PRIMARY KEY (media_asset_id)
);
GO

CREATE TABLE restaurant_menu.restaurant_media (
    restaurant_id BIGINT NOT NULL,
    media_asset_id BIGINT NOT NULL,
    display_sequence INT NOT NULL,
    media_role_code VARCHAR(30) NOT NULL,
    CONSTRAINT PK_restaurant_media PRIMARY KEY (restaurant_id, media_asset_id),
    CONSTRAINT FK_restaurant_media_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurant_menu.restaurant(restaurant_id),
    CONSTRAINT FK_restaurant_media_asset FOREIGN KEY (media_asset_id)
        REFERENCES restaurant_menu.media_asset(media_asset_id)
);
GO

CREATE TABLE restaurant_menu.menu_item_media (
    menu_item_id BIGINT NOT NULL,
    media_asset_id BIGINT NOT NULL,
    display_sequence INT NOT NULL,
    media_role_code VARCHAR(30) NOT NULL,
    CONSTRAINT PK_menu_item_media PRIMARY KEY (menu_item_id, media_asset_id),
    CONSTRAINT FK_menu_item_media_item FOREIGN KEY (menu_item_id)
        REFERENCES restaurant_menu.menu_item(menu_item_id),
    CONSTRAINT FK_menu_item_media_asset FOREIGN KEY (media_asset_id)
        REFERENCES restaurant_menu.media_asset(media_asset_id)
);
GO

CREATE TABLE restaurant_menu.menu_category_media (
    menu_category_id BIGINT NOT NULL,
    media_asset_id BIGINT NOT NULL,
    display_sequence INT NOT NULL,
    media_role_code VARCHAR(30) NOT NULL,
    CONSTRAINT PK_menu_category_media PRIMARY KEY (menu_category_id, media_asset_id),
    CONSTRAINT FK_menu_category_media_category FOREIGN KEY (menu_category_id)
        REFERENCES restaurant_menu.menu_category(menu_category_id),
    CONSTRAINT FK_menu_category_media_asset FOREIGN KEY (media_asset_id)
        REFERENCES restaurant_menu.media_asset(media_asset_id)
);
GO

/* ============================================================================
   14. OCR / menu extraction provenance
   ============================================================================ */

CREATE TABLE restaurant_menu.menu_extraction_batch (
    extraction_batch_id BIGINT NOT NULL,
    restaurant_id BIGINT NOT NULL,
    source_id BIGINT NOT NULL,
    extractor_version VARCHAR(100) NULL,
    started_at DATETIME2(3) NOT NULL,
    completed_at DATETIME2(3) NULL,
    status_code VARCHAR(30) NOT NULL,
    overall_confidence DECIMAL(6,5) NULL,
    CONSTRAINT PK_menu_extraction_batch PRIMARY KEY (extraction_batch_id),
    CONSTRAINT FK_menu_extraction_batch_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurant_menu.restaurant(restaurant_id),
    CONSTRAINT FK_menu_extraction_batch_source FOREIGN KEY (source_id)
        REFERENCES restaurant_menu.source_record(source_id),
    CONSTRAINT CK_menu_extraction_batch_confidence CHECK (
        overall_confidence IS NULL OR (overall_confidence >= 0 AND overall_confidence <= 1)
    )
);
GO

CREATE TABLE restaurant_menu.menu_extraction_image (
    extraction_image_id BIGINT NOT NULL,
    extraction_batch_id BIGINT NOT NULL,
    media_asset_id BIGINT NOT NULL,
    page_number INT NOT NULL,
    original_filename NVARCHAR(500) NULL,
    extracted_text_checksum VARCHAR(128) NULL,
    CONSTRAINT PK_menu_extraction_image PRIMARY KEY (extraction_image_id),
    CONSTRAINT FK_menu_extraction_image_batch FOREIGN KEY (extraction_batch_id)
        REFERENCES restaurant_menu.menu_extraction_batch(extraction_batch_id),
    CONSTRAINT FK_menu_extraction_image_asset FOREIGN KEY (media_asset_id)
        REFERENCES restaurant_menu.media_asset(media_asset_id),
    CONSTRAINT UQ_menu_extraction_image_page UNIQUE (extraction_batch_id, page_number),
    CONSTRAINT CK_menu_extraction_image_page CHECK (page_number > 0)
);
GO

CREATE TABLE restaurant_menu.menu_item_source (
    menu_item_id BIGINT NOT NULL,
    source_id BIGINT NOT NULL,
    extraction_batch_id BIGINT NULL,
    confidence DECIMAL(6,5) NULL,
    verification_status_code VARCHAR(30) NOT NULL,
    verified_at DATETIME2(3) NULL,
    CONSTRAINT PK_menu_item_source PRIMARY KEY (menu_item_id, source_id),
    CONSTRAINT FK_menu_item_source_item FOREIGN KEY (menu_item_id)
        REFERENCES restaurant_menu.menu_item(menu_item_id),
    CONSTRAINT FK_menu_item_source_source FOREIGN KEY (source_id)
        REFERENCES restaurant_menu.source_record(source_id),
    CONSTRAINT FK_menu_item_source_batch FOREIGN KEY (extraction_batch_id)
        REFERENCES restaurant_menu.menu_extraction_batch(extraction_batch_id),
    CONSTRAINT CK_menu_item_source_confidence CHECK (
        confidence IS NULL OR (confidence >= 0 AND confidence <= 1)
    )
);
GO

CREATE TABLE restaurant_menu.menu_item_price_source (
    price_id BIGINT NOT NULL,
    source_id BIGINT NOT NULL,
    extraction_batch_id BIGINT NULL,
    confidence DECIMAL(6,5) NULL,
    CONSTRAINT PK_menu_item_price_source PRIMARY KEY (price_id, source_id),
    CONSTRAINT FK_menu_item_price_source_price FOREIGN KEY (price_id)
        REFERENCES restaurant_menu.menu_item_price(price_id),
    CONSTRAINT FK_menu_item_price_source_source FOREIGN KEY (source_id)
        REFERENCES restaurant_menu.source_record(source_id),
    CONSTRAINT FK_menu_item_price_source_batch FOREIGN KEY (extraction_batch_id)
        REFERENCES restaurant_menu.menu_extraction_batch(extraction_batch_id),
    CONSTRAINT CK_menu_item_price_source_confidence CHECK (
        confidence IS NULL OR (confidence >= 0 AND confidence <= 1)
    )
);
GO

/* ============================================================================
   15. Delivery capability and provider support
   ============================================================================ */

CREATE TABLE restaurant_menu.delivery_provider (
    delivery_provider_id BIGINT NOT NULL,
    provider_code VARCHAR(50) NOT NULL,
    provider_name NVARCHAR(150) NOT NULL,
    provider_type_code VARCHAR(30) NOT NULL,
    is_active BIT NOT NULL,
    created_at DATETIME2(3) NOT NULL,
    updated_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_delivery_provider PRIMARY KEY (delivery_provider_id),
    CONSTRAINT UQ_delivery_provider_code UNIQUE (provider_code)
);
GO

CREATE TABLE restaurant_menu.restaurant_delivery (
    restaurant_id BIGINT NOT NULL,
    delivery_available BIT NOT NULL,
    self_delivery_available BIT NOT NULL,
    self_delivery_min_order_amount DECIMAL(12,2) NULL,
    currency_code CHAR(3) NULL,
    last_verified_at DATETIME2(3) NULL,
    status_code VARCHAR(30) NOT NULL,
    created_at DATETIME2(3) NOT NULL,
    updated_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_restaurant_delivery PRIMARY KEY (restaurant_id),
    CONSTRAINT FK_restaurant_delivery_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurant_menu.restaurant(restaurant_id),
    CONSTRAINT CK_restaurant_delivery_min_order CHECK (
        self_delivery_min_order_amount IS NULL OR self_delivery_min_order_amount >= 0
    )
);
GO

CREATE TABLE restaurant_menu.restaurant_delivery_provider (
    restaurant_delivery_provider_id BIGINT NOT NULL,
    restaurant_id BIGINT NOT NULL,
    delivery_provider_id BIGINT NOT NULL,
    is_available BIT NOT NULL,
    minimum_order_amount DECIMAL(12,2) NULL,
    base_delivery_charge DECIMAL(12,2) NULL,
    delivery_charge_type_code VARCHAR(30) NOT NULL,
    delivery_charge_percentage DECIMAL(7,4) NULL,
    free_delivery_min_order_amount DECIMAL(12,2) NULL,
    currency_code CHAR(3) NULL,
    effective_from DATETIME2(3) NOT NULL,
    effective_to DATETIME2(3) NULL,
    last_verified_at DATETIME2(3) NULL,
    created_at DATETIME2(3) NOT NULL,
    updated_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_restaurant_delivery_provider PRIMARY KEY (restaurant_delivery_provider_id),
    CONSTRAINT FK_restaurant_delivery_provider_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurant_menu.restaurant(restaurant_id),
    CONSTRAINT FK_restaurant_delivery_provider_provider FOREIGN KEY (delivery_provider_id)
        REFERENCES restaurant_menu.delivery_provider(delivery_provider_id),
    CONSTRAINT UQ_restaurant_delivery_provider_version
        UNIQUE (restaurant_id, delivery_provider_id, effective_from),
    CONSTRAINT CK_restaurant_delivery_provider_amounts CHECK (
        (minimum_order_amount IS NULL OR minimum_order_amount >= 0)
        AND (base_delivery_charge IS NULL OR base_delivery_charge >= 0)
        AND (delivery_charge_percentage IS NULL OR delivery_charge_percentage >= 0)
        AND (free_delivery_min_order_amount IS NULL OR free_delivery_min_order_amount >= 0)
    )
);
GO

CREATE TABLE restaurant_menu.menu_item_delivery (
    menu_item_delivery_id BIGINT NOT NULL,
    menu_item_id BIGINT NOT NULL,
    delivery_provider_id BIGINT NULL,
    delivery_status_code VARCHAR(30) NOT NULL,
    minimum_order_amount DECIMAL(12,2) NULL,
    reason_code VARCHAR(40) NULL,
    effective_from DATETIME2(3) NOT NULL,
    effective_to DATETIME2(3) NULL,
    last_verified_at DATETIME2(3) NULL,
    CONSTRAINT PK_menu_item_delivery PRIMARY KEY (menu_item_delivery_id),
    CONSTRAINT FK_menu_item_delivery_item FOREIGN KEY (menu_item_id)
        REFERENCES restaurant_menu.menu_item(menu_item_id),
    CONSTRAINT FK_menu_item_delivery_provider FOREIGN KEY (delivery_provider_id)
        REFERENCES restaurant_menu.delivery_provider(delivery_provider_id),
    CONSTRAINT CK_menu_item_delivery_min_order CHECK (
        minimum_order_amount IS NULL OR minimum_order_amount >= 0
    )
);
GO

/* ============================================================================
   16. Bounded transactional outbox
   ============================================================================ */

CREATE TABLE restaurant_menu.change_event_outbox (
    event_id BIGINT NOT NULL,
    aggregate_type VARCHAR(50) NOT NULL,
    aggregate_id BIGINT NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    occurred_at DATETIME2(3) NOT NULL,
    payload_text NVARCHAR(MAX) NOT NULL,
    publish_status_code VARCHAR(30) NOT NULL,
    attempt_count INT NOT NULL,
    next_attempt_at DATETIME2(3) NULL,
    published_at DATETIME2(3) NULL,
    expires_at DATETIME2(3) NOT NULL,
    CONSTRAINT PK_change_event_outbox PRIMARY KEY (event_id),
    CONSTRAINT CK_change_event_outbox_attempts CHECK (attempt_count >= 0)
);
GO

/* ============================================================================
   17. Recommended indexes
   ============================================================================ */

CREATE INDEX IX_restaurant_establishment ON restaurant_menu.restaurant(establishment_id);
CREATE INDEX IX_restaurant_brand ON restaurant_menu.restaurant(brand_id);
CREATE INDEX IX_restaurant_status ON restaurant_menu.restaurant(status_code);
CREATE INDEX IX_restaurant_normalized_name ON restaurant_menu.restaurant(normalized_name);
CREATE INDEX IX_restaurant_listing_tier ON restaurant_menu.restaurant(listing_tier_code);
CREATE INDEX IX_restaurant_last_verified ON restaurant_menu.restaurant(last_verified_at);
CREATE INDEX IX_restaurant_name_postal ON restaurant_menu.establishment(normalized_name, postal_code);

CREATE INDEX IX_external_identity_restaurant ON restaurant_menu.restaurant_external_identity(restaurant_id);

CREATE INDEX IX_restaurant_tag_tag ON restaurant_menu.restaurant_tag(tag_id, restaurant_id);

CREATE INDEX IX_restaurant_service_mode_active
    ON restaurant_menu.restaurant_service_mode(restaurant_id, is_active);

CREATE INDEX IX_restaurant_hours ON restaurant_menu.restaurant_hours(restaurant_id, day_of_week, slot_sequence);
CREATE INDEX IX_holiday_hours ON restaurant_menu.restaurant_holiday_hours(restaurant_id, holiday_date);

CREATE INDEX IX_brand_template_brand ON restaurant_menu.brand_menu_template(brand_id, is_active);
CREATE INDEX IX_template_item_template ON restaurant_menu.brand_menu_template_item(template_id);
CREATE INDEX IX_template_board_template ON restaurant_menu.brand_menu_template_board(template_id);

CREATE INDEX IX_canonical_dish_normalized ON restaurant_menu.canonical_dish(normalized_name);
CREATE INDEX IX_canonical_dish_classification ON restaurant_menu.canonical_dish(food_classification_code);
CREATE INDEX IX_canonical_dish_jain ON restaurant_menu.canonical_dish(is_jain);
CREATE INDEX IX_canonical_dish_vegan ON restaurant_menu.canonical_dish(is_vegan);

CREATE INDEX IX_canonical_dish_name_normalized ON restaurant_menu.canonical_dish_name(normalized_name);

CREATE INDEX IX_menu_board_restaurant_active
    ON restaurant_menu.menu_board(restaurant_id, is_active, display_sequence);
CREATE INDEX IX_menu_board_type_active
    ON restaurant_menu.menu_board(board_type_code, is_active);
CREATE INDEX IX_menu_board_instance_date
    ON restaurant_menu.menu_board_instance(menu_board_id, instance_date);

CREATE INDEX IX_menu_category_tree
    ON restaurant_menu.menu_category(restaurant_id, parent_category_id, display_sequence);

CREATE INDEX IX_menu_board_category_category
    ON restaurant_menu.menu_board_category(menu_category_id, menu_board_id);

CREATE INDEX IX_menu_item_restaurant_status
    ON restaurant_menu.menu_item(restaurant_id, status_code);
CREATE INDEX IX_menu_item_canonical ON restaurant_menu.menu_item(canonical_dish_id);
CREATE INDEX IX_menu_item_normalized ON restaurant_menu.menu_item(normalized_name);
CREATE INDEX IX_menu_item_classification ON restaurant_menu.menu_item(food_classification_code);
CREATE INDEX IX_menu_item_jain ON restaurant_menu.menu_item(is_jain);
CREATE INDEX IX_menu_item_vegan ON restaurant_menu.menu_item(is_vegan);
CREATE INDEX IX_menu_item_eggless ON restaurant_menu.menu_item(is_eggless);
CREATE INDEX IX_menu_item_template ON restaurant_menu.menu_item(template_item_id);

CREATE INDEX IX_menu_item_name_normalized ON restaurant_menu.menu_item_name(normalized_name);

CREATE INDEX IX_menu_board_item_item ON restaurant_menu.menu_board_item(menu_item_id);
CREATE INDEX IX_menu_board_item_display
    ON restaurant_menu.menu_board_item(menu_board_id, display_sequence);

CREATE INDEX IX_menu_board_instance_item_item
    ON restaurant_menu.menu_board_instance_item(menu_item_id);

CREATE INDEX IX_menu_item_variant_item_active
    ON restaurant_menu.menu_item_variant(menu_item_id, is_active);

CREATE INDEX IX_menu_item_price_current
    ON restaurant_menu.menu_item_price(variant_id, effective_from, effective_to);
CREATE INDEX IX_menu_item_price_service
    ON restaurant_menu.menu_item_price(variant_id, service_mode_id, effective_from);
CREATE INDEX IX_menu_item_price_schedule
    ON restaurant_menu.menu_item_price(price_schedule_id, effective_from);

CREATE INDEX IX_menu_item_charge_item_service
    ON restaurant_menu.menu_item_charge(menu_item_id, service_mode_id, effective_from);

CREATE INDEX IX_menu_item_availability
    ON restaurant_menu.menu_item_availability(menu_item_id, day_of_week, start_time);
CREATE INDEX IX_menu_item_availability_override
    ON restaurant_menu.menu_item_availability_override(menu_item_id, override_date);

CREATE INDEX IX_bundle_group_bundle ON restaurant_menu.bundle_group(bundle_id, display_sequence);
CREATE INDEX IX_bundle_component_bundle ON restaurant_menu.bundle_component(bundle_id, display_sequence);
CREATE INDEX IX_bundle_component_item ON restaurant_menu.bundle_component(component_menu_item_id);

CREATE INDEX IX_bar_product_type ON restaurant_menu.bar_product(product_type_code);
CREATE INDEX IX_bar_menu_item_product ON restaurant_menu.bar_menu_item(bar_product_id);
CREATE INDEX IX_cocktail_base_option_cocktail
    ON restaurant_menu.cocktail_base_option(cocktail_menu_item_id, is_default);

CREATE INDEX IX_restaurant_media_role ON restaurant_menu.restaurant_media(restaurant_id, media_role_code);
CREATE INDEX IX_menu_item_media_role ON restaurant_menu.menu_item_media(menu_item_id, media_role_code);
CREATE INDEX IX_menu_category_media_role ON restaurant_menu.menu_category_media(menu_category_id, media_role_code);

CREATE INDEX IX_extraction_batch_restaurant
    ON restaurant_menu.menu_extraction_batch(restaurant_id, started_at);
CREATE INDEX IX_extraction_image_batch
    ON restaurant_menu.menu_extraction_image(extraction_batch_id, page_number);
CREATE INDEX IX_menu_item_source_batch
    ON restaurant_menu.menu_item_source(extraction_batch_id);
CREATE INDEX IX_menu_item_price_source_batch
    ON restaurant_menu.menu_item_price_source(extraction_batch_id);

CREATE INDEX IX_delivery_provider_active
    ON restaurant_menu.delivery_provider(is_active, provider_type_code);

CREATE INDEX IX_restaurant_delivery_provider_restaurant
    ON restaurant_menu.restaurant_delivery_provider(restaurant_id, is_available, effective_from);
CREATE INDEX IX_restaurant_delivery_provider_provider
    ON restaurant_menu.restaurant_delivery_provider(delivery_provider_id, is_available, effective_from);

CREATE INDEX IX_menu_item_delivery_item
    ON restaurant_menu.menu_item_delivery(menu_item_id, delivery_provider_id, effective_from);
CREATE INDEX IX_menu_item_delivery_provider
    ON restaurant_menu.menu_item_delivery(delivery_provider_id, delivery_status_code);

CREATE INDEX IX_change_event_outbox_publish
    ON restaurant_menu.change_event_outbox(publish_status_code, next_attempt_at);
CREATE INDEX IX_change_event_outbox_aggregate
    ON restaurant_menu.change_event_outbox(aggregate_type, aggregate_id);
CREATE INDEX IX_change_event_outbox_event_time
    ON restaurant_menu.change_event_outbox(event_type, occurred_at);
CREATE INDEX IX_change_event_outbox_expiry
    ON restaurant_menu.change_event_outbox(expires_at);
GO

/*
===============================================================================
REFERENCE CODE VALUES TO BE SEEDED BY THE APPLICATION/REFERENCE-DATA MIGRATION

service_mode:
DINE_IN
TAKEAWAY
DELIVERY
DRIVE_THROUGH
ROOM_SERVICE
BULK_CATERING

platform_tag.tag_scope examples:
RESTAURANT_FORMAT
RESTAURANT_FILTER
MENU_ITEM

source_record.source_type_code examples:
ADMIN
OWNER
PARTNER_API
AI_MENU_EXTRACTION
IMPORTED

menu_board.board_type_code examples:
A_LA_CARTE
BUFFET
THALI
COMBO
BAR
BREAKFAST
LUNCH
DINNER
KIDS
DESSERT
ROOM_SERVICE
SEASONAL
CATERING

menu_item_variant.pricing_basis_code examples:
FIXED
PER_PIECE
PER_PLATE
PER_PERSON
PER_KG
PER_100G
PER_100ML
MARKET_PRICE

delivery_provider.provider_type_code:
SELF
THIRD_PARTY

menu_item_delivery.delivery_status_code:
AVAILABLE
NOT_AVAILABLE
CONDITIONAL

change_event_outbox.event_type:
price_changed
item_added
item_removed
menu_updated

Do not implement these as SQL Server CHECK/ENUM-style database enums unless there is a
specific governance reason. They are intentionally reference/application codes.
===============================================================================
*/
