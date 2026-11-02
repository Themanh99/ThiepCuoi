-- 003_invite_cards: thiệp mời riêng từng người (link đẹp theo tên <tên miền>/<slug>).
-- slug        : đường dẫn riêng, duy nhất (a-z0-9-, 2–40 ký tự). NULL với khách tự xác nhận trên web.
-- salutation  : xưng hô (Anh, Chị, Cô chú, Gia đình…) — hiển thị "Anh Tuấn" và điền {xung_ho} trong mẫu lời mời.
-- invite_text : lời mời riêng (trống = dùng mẫu chung settings.invite_template).
-- max_guests  : số người tối đa của lời mời (NULL = không giới hạn, tối đa 20).
ALTER TABLE invites ADD COLUMN slug TEXT;
ALTER TABLE invites ADD COLUMN salutation TEXT;
ALTER TABLE invites ADD COLUMN invite_text TEXT;
ALTER TABLE invites ADD COLUMN max_guests INTEGER;
CREATE UNIQUE INDEX IF NOT EXISTS idx_invites_slug ON invites (slug);
CREATE INDEX IF NOT EXISTS idx_invites_source ON invites (source, status);
