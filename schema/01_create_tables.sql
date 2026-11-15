BEGIN;

-- USERS: stores registered members and their system roles.
CREATE TABLE users (
    user_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) NOT NULL UNIQUE,
    giu_email VARCHAR(255) UNIQUE,
    member_type VARCHAR(20) NOT NULL,
    role VARCHAR(20) NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT users_member_type_check
        CHECK (member_type IN ('student', 'staff')),

    CONSTRAINT users_role_check
        CHECK (role IN ('rider', 'admin')),

    -- Staff may register without a GIU email.
    CONSTRAINT users_student_email_check
        CHECK (member_type <> 'student' OR giu_email IS NOT NULL),

    CONSTRAINT users_name_not_blank
        CHECK (LENGTH(TRIM(full_name)) > 0),

    CONSTRAINT users_phone_not_blank
        CHECK (LENGTH(TRIM(phone_number)) > 0)
);


-- ZONES: stores the designated operating areas.
CREATE TABLE zones (
    zone_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    zone_name VARCHAR(100) NOT NULL,
    designated_area TEXT NOT NULL,

    CONSTRAINT zones_name_not_blank
        CHECK (LENGTH(TRIM(zone_name)) > 0),

    CONSTRAINT zones_area_not_blank
        CHECK (LENGTH(TRIM(designated_area)) > 0)
);


-- SUBSCRIPTION PLANS: stores plans available for purchase.
CREATE TABLE subscription_plans (
    subscription_plan_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    plan_name VARCHAR(100) NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    usage_limit_minutes INTEGER NOT NULL,
    validity_days INTEGER NOT NULL,

    CONSTRAINT subscription_plans_price_check
        CHECK (price >= 0),

    CONSTRAINT subscription_plans_usage_check
        CHECK (usage_limit_minutes > 0),

    CONSTRAINT subscription_plans_validity_check
        CHECK (validity_days > 0),

    CONSTRAINT subscription_plans_name_not_blank
        CHECK (LENGTH(TRIM(plan_name)) > 0)
);

COMMIT;

BEGIN;

CREATE TABLE stations (
    station_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    qr_code VARCHAR(100) NOT NULL UNIQUE,
    station_name VARCHAR(100) NOT NULL,
    latitude NUMERIC(10,7) NOT NULL,
    longitude NUMERIC(10,7) NOT NULL,
    zone_id BIGINT NOT NULL,

    CONSTRAINT stations_latitude_check
        CHECK (latitude BETWEEN -90 AND 90),

    CONSTRAINT stations_longitude_check
        CHECK (longitude BETWEEN -180 AND 180),

    -- RESTRICT prevents deleting a zone while stations reference it.
    CONSTRAINT stations_zone_fk
        FOREIGN KEY (zone_id)
        REFERENCES zones (zone_id)
        ON DELETE RESTRICT
);

CREATE TABLE bikes (
    bike_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    qr_code VARCHAR(100) NOT NULL UNIQUE,
    battery_level INTEGER NOT NULL,
    bike_status VARCHAR(20) NOT NULL DEFAULT 'available',
    zone_id BIGINT NOT NULL,
    current_station_id BIGINT,

    CONSTRAINT bikes_battery_check
        CHECK (battery_level BETWEEN 0 AND 100),

    CONSTRAINT bikes_status_check
        CHECK (
            bike_status IN (
                'available', 'reserved', 'rented', 'maintenance'
            )
        ),

    -- RESTRICT preserves the designated zone of existing bikes.
    CONSTRAINT bikes_zone_fk
        FOREIGN KEY (zone_id)
        REFERENCES zones (zone_id)
        ON DELETE RESTRICT,

    -- RESTRICT requires undocking/reassigning bikes before deleting a station.
    CONSTRAINT bikes_current_station_fk
        FOREIGN KEY (current_station_id)
        REFERENCES stations (station_id)
        ON DELETE RESTRICT
);

COMMIT;

BEGIN;

-- Stores staff ID submissions for verification.
CREATE TABLE staff_verifications (
    staff_verification_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    id_image_url TEXT NOT NULL,
    verification_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    submitted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reviewed_by BIGINT,

    CONSTRAINT staff_verifications_status_check
        CHECK (
            verification_status IN ('pending', 'approved', 'rejected')
        ),

    CONSTRAINT staff_verifications_image_check
        CHECK (LENGTH(TRIM(id_image_url)) > 0),

    -- RESTRICT preserves verification records linked to a user.
    CONSTRAINT staff_verifications_user_fk
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE RESTRICT,

    -- RESTRICT preserves the identity of a recorded reviewer.
    CONSTRAINT staff_verifications_reviewer_fk
        FOREIGN KEY (reviewed_by)
        REFERENCES users (user_id)
        ON DELETE RESTRICT
);


-- Stores verification-code hashes, not the original codes.
CREATE TABLE verification_codes (
    verification_code_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    code_hash VARCHAR(255) NOT NULL,
    verification_method VARCHAR(20) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    verified_at TIMESTAMP,

    CONSTRAINT verification_codes_method_check
        CHECK (verification_method IN ('email', 'phone')),

    CONSTRAINT verification_codes_hash_check
        CHECK (LENGTH(TRIM(code_hash)) > 0),

    CONSTRAINT verification_codes_time_check
        CHECK (
            verified_at IS NULL OR verified_at <= expires_at
        ),

    -- CASCADE removes temporary verification codes with their user.
    CONSTRAINT verification_codes_user_fk
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE CASCADE
);

COMMIT;

BEGIN;

-- Each user can have at most one wallet.
CREATE TABLE wallets (
    wallet_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    balance NUMERIC(12,2) NOT NULL DEFAULT 0,

    CONSTRAINT wallets_balance_check
        CHECK (balance >= 0),

    -- RESTRICT prevents deleting a user while their wallet exists.
    CONSTRAINT wallets_user_fk
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE RESTRICT
);


-- Records each subscription purchased by a user.
CREATE TABLE user_subscriptions (
    user_subscription_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    subscription_plan_id BIGINT NOT NULL,
    purchase_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expiry_date TIMESTAMP NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',

    CONSTRAINT user_subscriptions_dates_check
        CHECK (expiry_date > purchase_date),

    CONSTRAINT user_subscriptions_status_check
        CHECK (status IN ('active', 'expired', 'cancelled')),

    -- RESTRICT preserves the owner of subscription records.
    CONSTRAINT user_subscriptions_user_fk
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE RESTRICT,

    -- RESTRICT prevents deleting plans referenced by purchases.
    CONSTRAINT user_subscriptions_plan_fk
        FOREIGN KEY (subscription_plan_id)
        REFERENCES subscription_plans (subscription_plan_id)
        ON DELETE RESTRICT
);

COMMIT;

BEGIN;

-- Records rides, including unfinished rides.
CREATE TABLE rentals (
    rental_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    bike_id BIGINT NOT NULL,
    end_station_id BIGINT,
    start_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    duration_minutes INTEGER,
    total_cost NUMERIC(10,2),
    penalty_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    user_subscription_id BIGINT,

    CONSTRAINT rentals_time_check
        CHECK (end_time IS NULL OR end_time >= start_time),

    CONSTRAINT rentals_duration_check
        CHECK (duration_minutes >= 0),

    CONSTRAINT rentals_cost_check
        CHECK (total_cost >= 0),

    CONSTRAINT rentals_penalty_check
        CHECK (penalty_amount >= 0),

    -- A completed ride must have its return station and final charge.
    CONSTRAINT rentals_completion_check
        CHECK (
            (
                end_time IS NULL
                AND end_station_id IS NULL
                AND duration_minutes IS NULL
                AND total_cost IS NULL
            )
            OR
            (
                end_time IS NOT NULL
                AND end_station_id IS NOT NULL
                AND duration_minutes IS NOT NULL
                AND total_cost IS NOT NULL
            )
        ),

    -- RESTRICT preserves the rider associated with historical rides.
    CONSTRAINT rentals_user_fk
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE RESTRICT,

    -- RESTRICT preserves the bike associated with historical rides.
    CONSTRAINT rentals_bike_fk
        FOREIGN KEY (bike_id)
        REFERENCES bikes (bike_id)
        ON DELETE RESTRICT,

    -- RESTRICT preserves the recorded return station.
    CONSTRAINT rentals_end_station_fk
        FOREIGN KEY (end_station_id)
        REFERENCES stations (station_id)
        ON DELETE RESTRICT,

    -- RESTRICT preserves the subscription used for a ride.
    CONSTRAINT rentals_subscription_fk
        FOREIGN KEY (user_subscription_id)
        REFERENCES user_subscriptions (user_subscription_id)
        ON DELETE RESTRICT
);

-- Prevents a bike from having two unfinished rides.
CREATE UNIQUE INDEX rentals_one_open_ride_per_bike
    ON rentals (bike_id)
    WHERE end_time IS NULL;


CREATE TABLE reservations (
    reservation_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    bike_id BIGINT NOT NULL,
    reservation_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expiry_time TIMESTAMP NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',

    CONSTRAINT reservations_time_check
        CHECK (expiry_time > reservation_time),

    CONSTRAINT reservations_status_check
        CHECK (
            status IN ('active', 'expired', 'cancelled', 'fulfilled')
        ),

    -- RESTRICT preserves the user associated with a reservation.
    CONSTRAINT reservations_user_fk
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE RESTRICT,

    -- RESTRICT preserves the bike associated with a reservation.
    CONSTRAINT reservations_bike_fk
        FOREIGN KEY (bike_id)
        REFERENCES bikes (bike_id)
        ON DELETE RESTRICT
);

-- Prevents two reservations marked active for the same bike.
CREATE UNIQUE INDEX reservations_one_active_per_bike
    ON reservations (bike_id)
    WHERE status = 'active';

COMMIT;

BEGIN;

-- Records wallet top-ups, ride charges, and subscription payments.
CREATE TABLE wallet_transactions (
    wallet_transaction_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    wallet_id BIGINT NOT NULL,
    rental_id BIGINT,
    user_subscription_id BIGINT,
    transaction_type VARCHAR(20) NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT wallet_transactions_amount_check
        CHECK (amount > 0),

    CONSTRAINT wallet_transactions_type_check
        CHECK (
            transaction_type IN (
                'top_up', 'ride_payment', 'subscription_payment'
            )
        ),

    -- Each transaction type must reference the appropriate purchase.
    CONSTRAINT wallet_transactions_reference_check
        CHECK (
            (
                transaction_type = 'top_up'
                AND rental_id IS NULL
                AND user_subscription_id IS NULL
            )
            OR
            (
                transaction_type = 'ride_payment'
                AND rental_id IS NOT NULL
                AND user_subscription_id IS NULL
            )
            OR
            (
                transaction_type = 'subscription_payment'
                AND rental_id IS NULL
                AND user_subscription_id IS NOT NULL
            )
        ),

    -- RESTRICT preserves the wallet linked to financial records.
    CONSTRAINT wallet_transactions_wallet_fk
        FOREIGN KEY (wallet_id)
        REFERENCES wallets (wallet_id)
        ON DELETE RESTRICT,

    -- RESTRICT preserves the ride linked to a payment.
    CONSTRAINT wallet_transactions_rental_fk
        FOREIGN KEY (rental_id)
        REFERENCES rentals (rental_id)
        ON DELETE RESTRICT,

    -- RESTRICT preserves the subscription linked to a payment.
    CONSTRAINT wallet_transactions_subscription_fk
        FOREIGN KEY (user_subscription_id)
        REFERENCES user_subscriptions (user_subscription_id)
        ON DELETE RESTRICT
);


-- Stores problems submitted by riders.
CREATE TABLE emergency_reports (
    emergency_report_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    bike_id BIGINT,
    report_type VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    report_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'open',

    CONSTRAINT emergency_reports_status_check
        CHECK (status IN ('open', 'in_progress', 'resolved')),

    CONSTRAINT emergency_reports_type_check
        CHECK (LENGTH(TRIM(report_type)) > 0),

    CONSTRAINT emergency_reports_description_check
        CHECK (LENGTH(TRIM(description)) > 0),

    -- RESTRICT preserves the reporting user's identity.
    CONSTRAINT emergency_reports_user_fk
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE RESTRICT,

    -- RESTRICT preserves the bike associated with a report.
    CONSTRAINT emergency_reports_bike_fk
        FOREIGN KEY (bike_id)
        REFERENCES bikes (bike_id)
        ON DELETE RESTRICT
);


-- Stores safety and fleet alerts.
CREATE TABLE safety_alerts (
    safety_alert_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bike_id BIGINT,
    user_id BIGINT,
    zone_id BIGINT,
    alert_type VARCHAR(50) NOT NULL,
    alert_description TEXT NOT NULL,
    alert_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'open',

    CONSTRAINT safety_alerts_status_check
        CHECK (status IN ('open', 'in_progress', 'resolved')),

    CONSTRAINT safety_alerts_type_check
        CHECK (LENGTH(TRIM(alert_type)) > 0),

    CONSTRAINT safety_alerts_description_check
        CHECK (LENGTH(TRIM(alert_description)) > 0),

    -- RESTRICT preserves the bike associated with an alert.
    CONSTRAINT safety_alerts_bike_fk
        FOREIGN KEY (bike_id)
        REFERENCES bikes (bike_id)
        ON DELETE RESTRICT,

    -- RESTRICT preserves the user associated with an alert.
    CONSTRAINT safety_alerts_user_fk
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE RESTRICT,

    -- RESTRICT preserves the zone associated with an alert.
    CONSTRAINT safety_alerts_zone_fk
        FOREIGN KEY (zone_id)
        REFERENCES zones (zone_id)
        ON DELETE RESTRICT
);


-- Stores timestamped GPS readings for each bike.
CREATE TABLE bike_locations (
    bike_location_id BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bike_id BIGINT NOT NULL,
    latitude NUMERIC(10,7) NOT NULL,
    longitude NUMERIC(10,7) NOT NULL,
    recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT bike_locations_latitude_check
        CHECK (latitude BETWEEN -90 AND 90),

    CONSTRAINT bike_locations_longitude_check
        CHECK (longitude BETWEEN -180 AND 180),

    -- RESTRICT preserves the bike linked to GPS history.
    CONSTRAINT bike_locations_bike_fk
        FOREIGN KEY (bike_id)
        REFERENCES bikes (bike_id)
        ON DELETE RESTRICT
);

COMMIT;
