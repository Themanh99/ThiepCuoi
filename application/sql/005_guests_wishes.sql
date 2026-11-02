-- 005_guests_wishes: vòng QA 1 (gói B).
-- wishes.updated_at   : lúc khách sửa lời chúc (trả lời lại thiệp với lời nhắn mới). NULL = chưa sửa.
--                       Sắp xếp theo COALESCE(updated_at, created_at), nhãn "đã sửa" ở quản trị.
-- invite_old_slugs    : link riêng cũ của khách sau khi chủ nhà đổi slug -> link đã gửi vẫn mở đúng thiệp,
--                       và slug cũ không cấp lại cho khách khác.
ALTER TABLE wishes ADD COLUMN updated_at TEXT;
CREATE TABLE IF NOT EXISTS invite_old_slugs (
    slug       TEXT PRIMARY KEY,
    invite_id  INTEGER NOT NULL,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_invite_old_slugs_invite ON invite_old_slugs (invite_id);
