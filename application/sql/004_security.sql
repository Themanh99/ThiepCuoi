-- 004_security: vòng QA 1 (gói A).
-- rate_events.device    : mã thiết bị (cookie ac_dev, 32 hex) — giới hạn theo thiết bị + trần theo IP
--                         để hàng trăm khách chung wifi tiệc cưới vẫn gửi được (D4). '' = sự kiện chỉ tính theo IP.
-- users.session_version : tăng mỗi lần đổi mật khẩu; phiên đăng nhập lưu số này, lệch -> bị đăng xuất.
ALTER TABLE rate_events ADD COLUMN device TEXT NOT NULL DEFAULT '';
CREATE INDEX IF NOT EXISTS idx_rate_events_device ON rate_events (scope, device, created_at);
ALTER TABLE users ADD COLUMN session_version INTEGER NOT NULL DEFAULT 0;
