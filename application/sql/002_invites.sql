-- 002_invites: giấy mời + xác nhận tham dự (RSVP).
-- Mỗi dòng là 1 lời mời. source = 'invite' (chủ nhà tạo, có link riêng /moi/<code>)
-- hoặc 'web' (khách tự điền form trên trang chính).
-- status: pending (chưa trả lời) | yes (tham dự) | no (không tham dự)
CREATE TABLE IF NOT EXISTS invites (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    code         TEXT NOT NULL UNIQUE,
    name         TEXT NOT NULL,
    phone        TEXT,
    side         TEXT,
    note         TEXT,
    source       TEXT NOT NULL DEFAULT 'invite',
    status       TEXT NOT NULL DEFAULT 'pending',
    guests       INTEGER NOT NULL DEFAULT 1,
    message      TEXT,
    wish_id      INTEGER,
    opened_at    TEXT,
    responded_at TEXT,
    created_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_invites_status ON invites (status);
