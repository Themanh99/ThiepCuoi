-- 001_init: schema khởi tạo của Ảnh Cưới. Libraries/Schema.php áp mỗi file .sql trong thư mục
-- này đúng 1 lần theo thứ tự tên, ghi vào app_migrations. File mới chỉ được ADD (bảng/cột/index).

CREATE TABLE IF NOT EXISTS settings (
    key   TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    username      TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    display_name  TEXT,
    created_at    TEXT NOT NULL,
    last_login_at TEXT
);

-- visibility: public (ai có link trang chủ cũng xem) | password (cần mật khẩu album) | hidden (chỉ chủ nhà)
CREATE TABLE IF NOT EXISTS albums (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    title              TEXT NOT NULL,
    slug               TEXT NOT NULL UNIQUE,
    description        TEXT,
    event_date         TEXT,
    cover_photo_id     INTEGER,
    visibility         TEXT NOT NULL DEFAULT 'public',
    password_hash      TEXT,
    allow_guest_upload INTEGER NOT NULL DEFAULT 0,
    sort_order         INTEGER NOT NULL DEFAULT 0,
    created_at         TEXT NOT NULL,
    updated_at         TEXT NOT NULL
);

-- file_key: 32 hex ngẫu nhiên — tên file trên đĩa (uploads/photos/<2 ký tự đầu>/<key>_{o,m,t}.<ext>).
-- Không đoán được nên ảnh của album ẩn/mật khẩu không lộ qua đường dẫn tĩnh.
-- status: approved | pending (khách gửi, chờ duyệt) | rejected
CREATE TABLE IF NOT EXISTS photos (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    album_id      INTEGER NOT NULL,
    file_key      TEXT NOT NULL UNIQUE,
    ext           TEXT NOT NULL,
    orig_name     TEXT,
    width         INTEGER,
    height        INTEGER,
    size_bytes    INTEGER,
    taken_at      TEXT,
    caption       TEXT,
    status        TEXT NOT NULL DEFAULT 'approved',
    source        TEXT NOT NULL DEFAULT 'owner',
    guest_name    TEXT,
    guest_message TEXT,
    uploader_ip   TEXT,
    sort_order    INTEGER NOT NULL DEFAULT 0,
    created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_photos_album_status ON photos (album_id, status, sort_order, id);
CREATE INDEX IF NOT EXISTS idx_photos_status ON photos (status, created_at);

-- Lời chúc của khách mời. status: approved | pending | hidden
CREATE TABLE IF NOT EXISTS wishes (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT NOT NULL,
    message    TEXT NOT NULL,
    status     TEXT NOT NULL DEFAULT 'approved',
    ip         TEXT,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_wishes_status ON wishes (status, id);

-- Nhật ký cho rate-limit (đăng nhập, mật khẩu album, khách gửi ảnh/lời chúc).
CREATE TABLE IF NOT EXISTS rate_events (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    scope      TEXT NOT NULL,
    ip         TEXT NOT NULL,
    created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rate_events ON rate_events (scope, ip, created_at);
