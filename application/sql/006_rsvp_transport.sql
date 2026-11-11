-- Empty = no shuttle booking; same_evening / next_day = return journey.
ALTER TABLE invites ADD COLUMN shuttle_return TEXT NOT NULL DEFAULT ''
    CHECK (shuttle_return IN ('', 'same_evening', 'next_day'));
