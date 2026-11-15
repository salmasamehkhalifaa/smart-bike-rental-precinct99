BEGIN;

-- Fictional users for testing only.
INSERT INTO users (
    full_name, phone_number, giu_email,
    member_type, role, is_verified
)
VALUES
    (
        'Demo Student', 'DEMO-001',
        'student@example.invalid',
        'student', 'rider', TRUE
    ),
    (
        'Demo Staff', 'DEMO-002', NULL,
        'staff', 'rider', TRUE
    ),
    (
        'Demo Administrator', 'DEMO-003',
        'admin@example.invalid',
        'staff', 'admin', TRUE
    );


-- Illustrative operating zones.
INSERT INTO zones (zone_name, designated_area)
VALUES
    ('Demo Campus', 'Illustrative campus operating area'),
    ('Demo Monorail', 'Illustrative monorail operating area'),
    ('Demo Residences', 'Illustrative residential operating area');


-- Illustrative prices and limits, not approved business values.
INSERT INTO subscription_plans (
    plan_name, price, usage_limit_minutes, validity_days
)
VALUES
    ('Demo Weekly', 100.00, 60, 7),
    ('Demo Monthly', 300.00, 300, 30),
    ('Demo Semester', 900.00, 1200, 120);

COMMIT;

BEGIN;

-- Fictional station locations for testing.
INSERT INTO stations (
    qr_code, station_name, latitude, longitude, zone_id
)
VALUES
    (
        'DEMO-STATION-001', 'Demo Campus Station',
        30.0000000, 31.0000000,
        (SELECT zone_id FROM zones
         WHERE zone_name = 'Demo Campus')
    ),
    (
        'DEMO-STATION-002', 'Demo Monorail Station',
        30.0100000, 31.0100000,
        (SELECT zone_id FROM zones
         WHERE zone_name = 'Demo Monorail')
    ),
    (
        'DEMO-STATION-003', 'Demo Residences Station',
        30.0200000, 31.0200000,
        (SELECT zone_id FROM zones
         WHERE zone_name = 'Demo Residences')
    );


INSERT INTO bikes (
    qr_code, battery_level, bike_status,
    zone_id, current_station_id
)
VALUES
    (
        'DEMO-BIKE-001', 90, 'available',
        (SELECT zone_id FROM zones
         WHERE zone_name = 'Demo Campus'),
        (SELECT station_id FROM stations
         WHERE qr_code = 'DEMO-STATION-001')
    ),
    (
        'DEMO-BIKE-002', 75, 'available',
        (SELECT zone_id FROM zones
         WHERE zone_name = 'Demo Monorail'),
        (SELECT station_id FROM stations
         WHERE qr_code = 'DEMO-STATION-002')
    ),
    (
        'DEMO-BIKE-003', 15, 'maintenance',
        (SELECT zone_id FROM zones
         WHERE zone_name = 'Demo Residences'),
        (SELECT station_id FROM stations
         WHERE qr_code = 'DEMO-STATION-003')
    );

COMMIT;

BEGIN;

-- Start each demo wallet at zero.
-- We will record top-ups and balances together later.
INSERT INTO wallets (user_id, balance)
SELECT user_id, 0
FROM users
WHERE phone_number IN ('DEMO-001', 'DEMO-002', 'DEMO-003');


-- Historical subscriptions for testing.
-- These are expired, so they do not imply unpaid active access.
INSERT INTO user_subscriptions (
    user_id, subscription_plan_id,
    purchase_date, expiry_date, status
)
VALUES
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-001'),
        (SELECT subscription_plan_id FROM subscription_plans
         WHERE plan_name = 'Demo Weekly'),
        TIMESTAMP '2026-09-01 09:00:00',
        TIMESTAMP '2026-09-08 09:00:00',
        'expired'
    ),
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-002'),
        (SELECT subscription_plan_id FROM subscription_plans
         WHERE plan_name = 'Demo Monthly'),
        TIMESTAMP '2026-09-01 09:00:00',
        TIMESTAMP '2026-10-01 09:00:00',
        'expired'
    ),
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-001'),
        (SELECT subscription_plan_id FROM subscription_plans
         WHERE plan_name = 'Demo Monthly'),
        TIMESTAMP '2026-10-01 09:00:00',
        TIMESTAMP '2026-10-31 09:00:00',
        'expired'
    );

COMMIT;

BEGIN;

-- Three historical ID submissions by the demo staff member.
INSERT INTO staff_verifications (
    user_id, id_image_url, verification_status,
    submitted_at, reviewed_by
)
VALUES
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-002'),
        'https://example.invalid/demo/staff-id-1.png',
        'rejected',
        TIMESTAMP '2026-08-01 09:00:00',
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-003')
    ),
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-002'),
        'https://example.invalid/demo/staff-id-2.png',
        'rejected',
        TIMESTAMP '2026-08-02 09:00:00',
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-003')
    ),
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-002'),
        'https://example.invalid/demo/staff-id-3.png',
        'approved',
        TIMESTAMP '2026-08-03 09:00:00',
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-003')
    );


-- Placeholder hashes for database testing only.
-- These values are not usable authentication credentials.
INSERT INTO verification_codes (
    user_id, code_hash, verification_method,
    expires_at, verified_at
)
VALUES
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-001'),
        'DEMO-PLACEHOLDER-HASH-001',
        'email',
        TIMESTAMP '2026-08-01 09:10:00',
        TIMESTAMP '2026-08-01 09:05:00'
    ),
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-002'),
        'DEMO-PLACEHOLDER-HASH-002',
        'phone',
        TIMESTAMP '2026-08-03 09:10:00',
        TIMESTAMP '2026-08-03 09:05:00'
    ),
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-003'),
        'DEMO-PLACEHOLDER-HASH-003',
        'email',
        TIMESTAMP '2026-08-01 10:10:00',
        TIMESTAMP '2026-08-01 10:05:00'
    );

COMMIT;

BEGIN;

-- Completed demo rides.
-- Costs are illustrative; no pricing calculation is performed here.
INSERT INTO rentals (
    user_id, bike_id, end_station_id,
    start_time, end_time, duration_minutes,
    total_cost, penalty_amount, user_subscription_id
)
VALUES
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-001'),
        (SELECT bike_id FROM bikes
         WHERE qr_code = 'DEMO-BIKE-001'),
        (SELECT station_id FROM stations
         WHERE qr_code = 'DEMO-STATION-001'),
        TIMESTAMP '2026-11-01 09:00:00',
        TIMESTAMP '2026-11-01 09:20:00',
        20, 20.00, 0, NULL
    ),
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-002'),
        (SELECT bike_id FROM bikes
         WHERE qr_code = 'DEMO-BIKE-002'),
        (SELECT station_id FROM stations
         WHERE qr_code = 'DEMO-STATION-002'),
        TIMESTAMP '2026-11-02 10:00:00',
        TIMESTAMP '2026-11-02 10:30:00',
        30, 30.00, 0, NULL
    ),
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-001'),
        (SELECT bike_id FROM bikes
         WHERE qr_code = 'DEMO-BIKE-001'),
        (SELECT station_id FROM stations
         WHERE qr_code = 'DEMO-STATION-001'),
        TIMESTAMP '2026-11-03 11:00:00',
        TIMESTAMP '2026-11-03 11:15:00',
        15, 15.00, 0, NULL
    );


-- Historical reservations: none currently blocks a bike.
INSERT INTO reservations (
    user_id, bike_id,
    reservation_time, expiry_time, status
)
VALUES
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-001'),
        (SELECT bike_id FROM bikes
         WHERE qr_code = 'DEMO-BIKE-001'),
        TIMESTAMP '2026-11-01 08:55:00',
        TIMESTAMP '2026-11-01 09:05:00',
        'fulfilled'
    ),
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-002'),
        (SELECT bike_id FROM bikes
         WHERE qr_code = 'DEMO-BIKE-002'),
        TIMESTAMP '2026-11-02 09:55:00',
        TIMESTAMP '2026-11-02 10:05:00',
        'fulfilled'
    ),
    (
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-001'),
        (SELECT bike_id FROM bikes
         WHERE qr_code = 'DEMO-BIKE-002'),
        TIMESTAMP '2026-11-04 12:00:00',
        TIMESTAMP '2026-11-04 12:10:00',
        'expired'
    );

COMMIT;

BEGIN;

-- Add a fictional top-up to each demo wallet.
INSERT INTO wallet_transactions (
    wallet_id, transaction_type, amount, transaction_date
)
SELECT
    w.wallet_id,
    'top_up',
    1000.00,
    TIMESTAMP '2026-08-31 09:00:00'
FROM wallets w
JOIN users u ON u.user_id = w.user_id
WHERE u.phone_number IN ('DEMO-001', 'DEMO-002', 'DEMO-003');


-- Record payment for each demo subscription.
INSERT INTO wallet_transactions (
    wallet_id, user_subscription_id,
    transaction_type, amount, transaction_date
)
SELECT
    w.wallet_id,
    s.user_subscription_id,
    'subscription_payment',
    p.price,
    s.purchase_date
FROM user_subscriptions s
JOIN subscription_plans p
    ON p.subscription_plan_id = s.subscription_plan_id
JOIN wallets w ON w.user_id = s.user_id
JOIN users u ON u.user_id = s.user_id
WHERE u.phone_number IN ('DEMO-001', 'DEMO-002');


-- Record payment for each completed demo ride.
INSERT INTO wallet_transactions (
    wallet_id, rental_id,
    transaction_type, amount, transaction_date
)
SELECT
    w.wallet_id,
    r.rental_id,
    'ride_payment',
    r.total_cost,
    r.end_time
FROM rentals r
JOIN wallets w ON w.user_id = r.user_id
JOIN users u ON u.user_id = r.user_id
WHERE u.phone_number IN ('DEMO-001', 'DEMO-002')
  AND r.end_time IS NOT NULL;


-- Set demo balances to top-ups minus recorded payments.
UPDATE wallets w
SET balance = (
    SELECT COALESCE(
        SUM(
            CASE
                WHEN t.transaction_type = 'top_up'
                    THEN t.amount
                ELSE -t.amount
            END
        ),
        0
    )
    FROM wallet_transactions t
    WHERE t.wallet_id = w.wallet_id
)
WHERE w.user_id IN (
    SELECT user_id
    FROM users
    WHERE phone_number IN ('DEMO-001', 'DEMO-002', 'DEMO-003')
);

COMMIT;

BEGIN;

-- Fictional resolved reports.
INSERT INTO emergency_reports (
    user_id, bike_id, report_type,
    description, report_time, status
)
SELECT
    u.user_id,
    b.bike_id,
    d.report_type,
    d.description,
    d.report_time,
    'resolved'
FROM (
    VALUES
        (
            'DEMO-001', 'DEMO-BIKE-001', 'general',
            'Demo report: rider requested assistance.',
            TIMESTAMP '2026-11-01 09:10:00'
        ),
        (
            'DEMO-002', 'DEMO-BIKE-002', 'tire',
            'Demo report: rider requested a tire inspection.',
            TIMESTAMP '2026-11-02 10:15:00'
        ),
        (
            'DEMO-001', 'DEMO-BIKE-001', 'general',
            'Demo report: rider requested help with the lock.',
            TIMESTAMP '2026-11-03 11:10:00'
        )
) AS d(phone, bike_qr, report_type, description, report_time)
JOIN users u ON u.phone_number = d.phone
JOIN bikes b ON b.qr_code = d.bike_qr;


-- Fictional historical alerts, entered manually for testing.
INSERT INTO safety_alerts (
    bike_id, user_id, zone_id,
    alert_type, alert_description, alert_time, status
)
VALUES
    (
        (SELECT bike_id FROM bikes
         WHERE qr_code = 'DEMO-BIKE-001'),
        (SELECT user_id FROM users
         WHERE phone_number = 'DEMO-001'),
        (SELECT zone_id FROM zones
         WHERE zone_name = 'Demo Campus'),
        'prolonged_stop',
        'Demo alert: rider stopped for over ten minutes.',
        TIMESTAMP '2026-11-01 09:15:00',
        'resolved'
    ),
    (
        NULL,
        NULL,
        (SELECT zone_id FROM zones
         WHERE zone_name = 'Demo Monorail'),
        'low_stock',
        'Demo alert: fewer than five bikes in the zone.',
        TIMESTAMP '2026-11-04 12:00:00',
        'resolved'
    ),
    (
        (SELECT bike_id FROM bikes
         WHERE qr_code = 'DEMO-BIKE-003'),
        NULL,
        (SELECT zone_id FROM zones
         WHERE zone_name = 'Demo Residences'),
        'midnight_return',
        'Demo alert: bike was not at the monorail at midnight.',
        TIMESTAMP '2026-11-05 00:00:00',
        'resolved'
    );


-- Illustrative GPS readings, not actual campus coordinates.
INSERT INTO bike_locations (
    bike_id, latitude, longitude, recorded_at
)
SELECT
    b.bike_id,
    s.latitude,
    s.longitude,
    TIMESTAMP '2026-11-05 08:00:00'
FROM bikes b
JOIN stations s ON s.station_id = b.current_station_id
WHERE b.qr_code IN (
    'DEMO-BIKE-001', 'DEMO-BIKE-002', 'DEMO-BIKE-003'
);

COMMIT;