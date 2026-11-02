#!/bin/bash
# Entrypoint cho Docker container – Ảnh Cưới
# Chạy PHP built-in server + nhịp gõ /health (dọn ảnh mồ côi, tạo ảnh nhỏ)
set -e

WEB_ROOT="/var/www/anhcuoi"
DB_DIR="$WEB_ROOT/database"

PORT="${ANHCUOI_PORT:-8686}"
BIND="${ANHCUOI_BIND:-0.0.0.0}"
WORKERS="${PHP_CLI_SERVER_WORKERS:-4}"

# ─── Tạo thư mục nếu chưa có (volume mount có thể rỗng lần đầu) ─────────────
mkdir -p "$DB_DIR/sessions" "$WEB_ROOT/uploads/photos" "$WEB_ROOT/uploads/media" 2>/dev/null || true
chmod 0700 "$DB_DIR" 2>/dev/null || true

# Ghi cổng để ứng dụng biết
printf '%s' "$PORT" > "$DB_DIR/.app_port" 2>/dev/null || true

echo "========================================"
echo "  Ảnh Cưới – Docker (không gọi ra ngoài)"
echo "  Container : http://0.0.0.0:$PORT"
echo "========================================"

# ─── Nhịp gõ /health mỗi phút ────────────────────────────────────────────────
(
    # Chờ PHP sẵn sàng (tối đa ~10 s)
    for _ in $(seq 1 20); do
        sleep 0.5
        curl -s -o /dev/null --max-time 2 "http://localhost:$PORT/health" && break
    done
    while true; do
        curl -s -o /dev/null --max-time 60 "http://localhost:$PORT/health?beat=1" || true
        sleep 60
    done
) &

# ─── Chạy PHP built-in server ────────────────────────────────────────────────
cd "$WEB_ROOT"

if [ "${WORKERS:-0}" -gt 1 ] 2>/dev/null; then
    export PHP_CLI_SERVER_WORKERS="$WORKERS"
else
    unset PHP_CLI_SERVER_WORKERS
fi

exec php \
    -S "$BIND:$PORT" \
    docker/router.php
