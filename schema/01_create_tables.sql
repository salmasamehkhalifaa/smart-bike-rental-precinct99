-- 1. Independent Tables (No Foreign Keys)
CREATE TABLE users (
    user_id BIGSERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    giu_email VARCHAR(255) UNIQUE,
    role VARCHAR(20) NOT NULL,
    is_verified BOOLEAN NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE subscription_plans (
    plan_id BIGSERIAL PRIMARY KEY,
    plan_name VARCHAR(100) NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    usage_limit_minutes INTEGER NOT NULL,
    validity_days INTEGER NOT NULL
);

-- 2. Tables with Foreign Keys pointing to the independent tables
CREATE TABLE staff_verifications (
    verification_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id),
    id_image_url TEXT NOT NULL,
    verification_status VARCHAR(20) NOT NULL,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_by BIGINT REFERENCES users(user_id)
);

CREATE TABLE user_subscriptions (
    user_subscription_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id),
    plan_id BIGINT NOT NULL REFERENCES subscription_plans(plan_id),
    purchase_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expiry_date TIMESTAMP NOT NULL,
    status VARCHAR(20) NOT NULL
);

-- 3. Transactional/Junction Tables (Depend on multiple tables)
CREATE TABLE rentals (
    rental_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id),
    bike_id BIGINT NOT NULL, -- Will reference bikes table once created
    end_station_id BIGINT,   -- Will reference stations table once created
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    duration_minutes INTEGER,
    total_cost NUMERIC(10,2),
    penalty_amount NUMERIC(10,2)
);