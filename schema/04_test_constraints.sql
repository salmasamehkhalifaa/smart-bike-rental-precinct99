DO $$
BEGIN
    -- TEST 1: Duplicate email must be rejected.
    BEGIN
        UPDATE users
        SET giu_email = 'student@example.invalid'
        WHERE phone_number = 'DEMO-002';

        RAISE EXCEPTION 'FAIL: duplicate email was accepted';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'PASS 1: duplicate email rejected';
    END;


    -- TEST 2: A missing foreign-key reference must be rejected.
    BEGIN
        UPDATE bikes
        SET zone_id = (
            SELECT MIN(zone_id) - 1
            FROM zones
        )
        WHERE qr_code = 'DEMO-BIKE-001';

        RAISE EXCEPTION 'FAIL: nonexistent zone was accepted';
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'PASS 2: nonexistent zone rejected';
    END;


    -- TEST 3: Invalid bike status must be rejected.
    BEGIN
        UPDATE bikes
        SET bike_status = 'flying'
        WHERE qr_code = 'DEMO-BIKE-001';

        RAISE EXCEPTION 'FAIL: invalid status was accepted';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'PASS 3: invalid status rejected';
    END;


    -- TEST 4: Battery above 100 must be rejected.
    BEGIN
        UPDATE bikes
        SET battery_level = 150
        WHERE qr_code = 'DEMO-BIKE-001';

        RAISE EXCEPTION 'FAIL: invalid battery level was accepted';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'PASS 4: invalid battery level rejected';
    END;


    -- TEST 5: Negative wallet balance must be rejected.
    BEGIN
        UPDATE wallets
        SET balance = -10
        WHERE user_id = (
            SELECT user_id
            FROM users
            WHERE phone_number = 'DEMO-001'
        );

        RAISE EXCEPTION 'FAIL: negative balance was accepted';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'PASS 5: negative balance rejected';
    END;


    -- TEST 6: Mandatory name must not be NULL.
    BEGIN
        UPDATE users
        SET full_name = NULL
        WHERE phone_number = 'DEMO-001';

        RAISE EXCEPTION 'FAIL: missing name was accepted';
    EXCEPTION
        WHEN not_null_violation THEN
            RAISE NOTICE 'PASS 6: missing name rejected';
    END;
END;
$$;
-- Test that two riders cannot actively reserve the same bike.
-- ROLLBACK removes the test reservations afterward.
BEGIN;

DO $$
DECLARE
    student_id BIGINT;
    staff_id BIGINT;
    test_bike_id BIGINT;
    violated_constraint TEXT;
BEGIN
    SELECT user_id INTO STRICT student_id
    FROM users WHERE phone_number = 'DEMO-001';

    SELECT user_id INTO STRICT staff_id
    FROM users WHERE phone_number = 'DEMO-002';

    SELECT bike_id INTO STRICT test_bike_id
    FROM bikes WHERE qr_code = 'DEMO-BIKE-001';

    INSERT INTO reservations (
        user_id, bike_id, reservation_time, expiry_time, status
    )
    VALUES (
        student_id, test_bike_id,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP + INTERVAL '10 minutes',
        'active'
    );

    BEGIN
        INSERT INTO reservations (
            user_id, bike_id, reservation_time, expiry_time, status
        )
        VALUES (
            staff_id, test_bike_id,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP + INTERVAL '10 minutes',
            'active'
        );

        RAISE EXCEPTION
            'FAIL: two active reservations were accepted';
    EXCEPTION
        WHEN unique_violation THEN
            GET STACKED DIAGNOSTICS
                violated_constraint = CONSTRAINT_NAME;

            IF violated_constraint <>
                'reservations_one_active_per_bike' THEN
                RAISE;
            END IF;

            RAISE NOTICE
                'PASS 7: second active reservation rejected';
    END;
END;
$$;

ROLLBACK;