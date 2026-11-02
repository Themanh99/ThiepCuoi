#!/bin/bash
# Chạy Ảnh Cưới trên macOS/Linux: PHP built-in server + (tùy chọn) Cloudflare Tunnel.
#   bash run_mac.sh                 # http://localhost:8686
#   ANHCUOI_BIND=0.0.0.0 bash run_mac.sh   # cho máy khác trong mạng nhà mở http://<ip-máy>:8686
#   ANHCUOI_PORT=9000 bash run_mac.sh      # cổng khác (bận thì lùi 9001/9002)
# Link công khai do WEB tự quản (Web/application/libraries/Tunnelrunner.php): cài xong tự có
# https://xxxx.jagame.vn; script này chỉ chạy PHP, tải cloudflared lần đầu và gõ /health mỗi phút.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Bố cục: RELEASE (phẳng, router.php cùng cấp) hay DEV (Web/ + Tools/ tách) ─
if [ -f "$SCRIPT_DIR/router.php" ]; then
    WEB_ROOT="$SCRIPT_DIR"
    CF_TOOL_DIR="$SCRIPT_DIR/cloudflared"
else
    ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    WEB_ROOT="$ROOT_DIR/Web"
    CF_TOOL_DIR="$ROOT_DIR/Tools/cloudflared"
fi
# Cấu hình tunnel luôn nằm trong web root (Quản trị ghi vào đây).
CF_CONF_DIR="$WEB_ROOT/cloudflared"
DB_DIR="$WEB_ROOT/database"
mkdir -p "$CF_CONF_DIR" "$DB_DIR/sessions" "$WEB_ROOT/uploads/photos" 2>/dev/null
chmod 0700 "$CF_CONF_DIR" "$DB_DIR" 2>/dev/null

BIND="${ANHCUOI_BIND:-localhost}"

# ─── PHP ──────────────────────────────────────────────────────────────────────
PHP_EXE="$(command -v php 2>/dev/null)"
APT_CMD="sudo apt install php-cli php-sqlite3 php-gd php-zip php-curl php-mbstring curl unzip"
if [ -z "$PHP_EXE" ]; then
    echo "[LỖI] Không tìm thấy PHP."
    echo "      macOS         : brew install php"
    echo "      Ubuntu/Debian : $APT_CMD"
    exit 1
fi
# Tiện ích bắt buộc: sqlite3 (dữ liệu), gd (ảnh), curl (link xxxx.jagame.vn), mbstring (chữ tiếng Việt).
MISSING=""
PHP_MODS="$("$PHP_EXE" -m 2>/dev/null)"
for ext in sqlite3 gd curl mbstring; do
    printf '%s\n' "$PHP_MODS" | grep -qi "^$ext\$" || MISSING="$MISSING php-$ext"
done
if [ -n "$MISSING" ]; then
    echo "[LỖI] PHP thiếu tiện ích:$MISSING"
    echo "      Ubuntu/Debian: $APT_CMD"
    echo "      macOS: brew reinstall php"
    echo "      Cài xong chạy lại: bash run_mac.sh"
    exit 1
fi
printf '%s\n' "$PHP_MODS" | grep -qi '^zip$' || echo "[!] PHP thiếu php-zip: khách sẽ không tải được cả album dạng .zip.  ($APT_CMD)"

# ─── Dọn PHP mồ côi CỦA ĐÚNG THƯ MỤC NÀY (R5-04) ─────────────────────────────
# php -S nhiều tiến trình: tiến trình chính chết (kill -9, hết RAM) thì các worker vẫn giữ cổng (PPID 1) -> lần chạy
# lại phải lùi cổng, 3 lần là hết cổng. Chỉ giết "php … -S … router.php" có thư mục làm việc = web root này VÀ đã mất
# cha (cha không còn là php / run_mac.sh / một shell). PHP của chương trình khác, hay Ảnh Cưới đang chạy ở cửa sổ
# khác cùng thư mục, không bị đụng (BL-13).
WEB_REAL="$(cd "$WEB_ROOT" && pwd -P)"
orphan_php_pids() {
    local pid ppid pcmd cands=""
    for pid in $(pgrep -f 'php.* -S [^ ]*:[0-9]+ router\.php' 2>/dev/null); do
        # Phải đúng là chương trình php (không phải shell có chữ "php -S" trong dòng lệnh).
        case "$(ps -o comm= -p "$pid" 2>/dev/null)" in *php*) ;; *) continue ;; esac
        # Xét cha trước (ps nhanh); thư mục làm việc xét 1 lần cho cả nhóm (lsof chậm ~1 s mỗi lần gọi trên macOS).
        ppid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
        [ -n "$ppid" ] || continue
        if [ "$ppid" != "1" ]; then
            pcmd="$(ps -o command= -p "$ppid" 2>/dev/null)"
            case "$pcmd" in
                *php*|*run_mac.sh*|*keepalive_mac.sh*) continue ;;
                -*|*/sh|*/bash|*/zsh|*/fish|*/dash|sh|bash|zsh|fish|dash|"sh "*|"bash "*|"zsh "*|"dash "*|*"/sh "*|*"/bash "*|*"/zsh "*|*"/dash "*) continue ;;
            esac
        fi
        cands="$cands $pid"
    done
    [ -n "$cands" ] || return 0
    if [ -d /proc/self ]; then
        for pid in $cands; do
            [ "$(readlink "/proc/$pid/cwd" 2>/dev/null)" = "$WEB_REAL" ] && echo "$pid"
        done
    elif command -v lsof >/dev/null 2>&1; then
        # -Fpn: dòng "p<pid>" rồi "n<thư mục>"
        lsof -a -p "$(echo $cands | tr ' ' ',')" -d cwd -Fpn 2>/dev/null | awk -v want="$WEB_REAL" '
            /^p/ { pid = substr($0, 2) } /^n/ { if (substr($0, 2) == want) print pid }'
    fi
}
kill_orphan_php() {
    local pids i
    pids="$(orphan_php_pids)"
    [ -n "$pids" ] || return 0
    kill $pids 2>/dev/null
    for i in 1 2 3 4 5 6 7 8 9 10; do
        sleep 0.3
        pids="$(for p in $pids; do kill -0 "$p" 2>/dev/null && echo "$p"; done)"
        [ -z "$pids" ] && return 0
    done
    kill -9 $pids 2>/dev/null
    return 0
}
STALE="$(orphan_php_pids)"
if [ -n "$STALE" ]; then
    echo "[!] Dọn $(printf '%s\n' $STALE | wc -l | tr -d ' ') tiến trình PHP cũ của Ảnh Cưới còn giữ cổng (lần chạy trước bị tắt đột ngột)."
    kill_orphan_php
fi

# ─── Chọn cổng: 8686 bận thì lùi 8687/8688 ───────────────────────────────────
port_busy() {
    if command -v lsof >/dev/null 2>&1; then
        lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
        return $?
    fi
    "$PHP_EXE" -r '$c=@fsockopen("127.0.0.1",(int)$argv[1],$e,$s,0.5); if($c){fclose($c); exit(0);} exit(1);' "$1" >/dev/null 2>&1
}
# ANHCUOI_PORT=<cổng>: đổi cổng gốc (vd máy đã có chương trình khác ở 8686); lùi tối đa 2 cổng kế tiếp.
BASE_PORT="${ANHCUOI_PORT:-8686}"
case "$BASE_PORT" in ''|*[!0-9]*) BASE_PORT=8686 ;; esac
PORTS="$BASE_PORT $((BASE_PORT + 1)) $((BASE_PORT + 2))"
PORT=""
for CAND in $PORTS; do
    if port_busy "$CAND"; then
        echo "[!] Cổng $CAND đang bận (có thể Ảnh Cưới đang chạy ở cửa sổ khác), thử cổng khác..."
        continue
    fi
    PORT="$CAND"
    break
done
if [ -z "$PORT" ]; then
    echo "[LỖI] Cả 3 cổng $(echo "$PORTS" | sed 's/ /, /g') đều bận. Đóng bớt cửa sổ Ảnh Cưới cũ rồi mở lại."
    exit 1
fi
printf '%s' "$PORT" > "$DB_DIR/.app_port" 2>/dev/null

# ─── Cấu hình tunnel ─────────────────────────────────────────────────────────
json_get() {  # json_get <file> <key>
    "$PHP_EXE" -r '$p=json_decode((string)@file_get_contents($argv[1]),true); echo is_array($p)?(string)($p[$argv[2]]??""):"";' "$1" "$2" 2>/dev/null
}
TUN_FILE="$CF_CONF_DIR/tunnel.json"
rm -f "$DB_DIR/.public_url" 2>/dev/null
# R3-07: lần chạy trước (vd keepalive chạy lại sau 5 s) để lại dấu .ensure_at còn mới -> nhịp /health đầu tiên bị
# bỏ qua và link chết thêm ~1 phút. Mới khởi động thì luôn cho web bật tunnel ngay.
rm -f "$CF_CONF_DIR/.ensure_at" 2>/dev/null

# ─── cloudflared: WEB tự bật/giám sát tunnel (Tunnelrunner.php); script chỉ bảo đảm có sẵn chương trình ───
if [ ! -x "$CF_TOOL_DIR/cloudflared" ] && ! command -v cloudflared >/dev/null 2>&1; then
    echo "  Đang tải cloudflared (lần đầu)..."
    mkdir -p "$CF_TOOL_DIR"
    OS="$(uname -s)"; ARCH="$(uname -m)"
    case "$ARCH" in arm64|aarch64) A=arm64 ;; *) A=amd64 ;; esac
    TMPF="$(mktemp /tmp/cf_dl_XXXXXX)"
    if [ "$OS" = "Darwin" ]; then
        curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-$A.tgz" -o "$TMPF" \
            && tar xzf "$TMPF" -C "$CF_TOOL_DIR/" 2>/dev/null
    else
        curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$A" -o "$CF_TOOL_DIR/cloudflared"
    fi
    rm -f "$TMPF"
    chmod +x "$CF_TOOL_DIR/cloudflared" 2>/dev/null
    [ -x "$CF_TOOL_DIR/cloudflared" ] || echo "  [!] Không tải được cloudflared — trang chỉ mở được trong máy/mạng nhà."
fi

echo "========================================"
echo "  Ảnh Cưới"
echo "  Máy này : http://localhost:$PORT      (quản trị: /admin)"
[ "$BIND" = "0.0.0.0" ] && echo "  Mạng nhà: http://<địa-chỉ-IP-máy-này>:$PORT"
echo "  Internet: link riêng xxxx.jagame.vn tự tạo sau khi cài đặt xong"
echo "  Nhấn Ctrl+C để dừng"
echo "========================================"

# ─── Dọn dẹp khi thoát: tắt nhịp gõ + tunnel do web bật (nhận ra qua file cấu hình riêng) ───
# Chỉ bẫy EXIT (chạy đúng 1 lần); Ctrl+C/TERM chỉ "exit 130" để đi vào EXIT. Tiến trình nền trong script
# không tương tác bỏ qua SIGINT, nên phải tự tắt cả con của chúng (sleep/curl), không để mồ côi (R2-31).
BEAT_PID=""
OPEN_PID=""
stop_tree() {  # stop_tree <pid>: tắt tiến trình và các con trực tiếp của nó
    [ -n "$1" ] || return 0
    local kids
    kids="$(pgrep -P "$1" 2>/dev/null)"
    kill "$1" 2>/dev/null
    [ -n "$kids" ] && kill $kids 2>/dev/null
    return 0
}
PHP_PID=""
FILTER_PID=""
LOG_FIFO=""
cleanup() {
    trap - EXIT INT TERM
    stop_tree "$BEAT_PID"
    stop_tree "$OPEN_PID"
    # PHP + các worker của nó (R5-04). PHP chính đã chết trước (kill -9) thì worker thành mồ côi: dọn theo thư mục.
    stop_tree "$PHP_PID"
    # Thu hồi job PHP NGAY (stderr tắt): bash chỉ in "Terminated: 15 …php…" khi job chết vì tín hiệu mà chưa được
    # wait trước lệnh ngoài kế tiếp (pgrep/ps trong kill_orphan_php) — S1-FREE-04.
    [ -n "$PHP_PID" ] && wait "$PHP_PID" 2>/dev/null
    kill_orphan_php
    pkill -f "cloudflared.*$CF_CONF_DIR/anhcuoi-tunnel.yml" 2>/dev/null
    [ -n "$FILTER_PID" ] && kill "$FILTER_PID" 2>/dev/null
    [ -n "$LOG_FIFO" ] && rm -rf "$(dirname "$LOG_FIFO")" 2>/dev/null
    rm -f "$CF_CONF_DIR/web_tunnel.pid" "$DB_DIR/.public_url" 2>/dev/null
    echo ""
    echo "Đã dừng."
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# ─── Nhịp gõ: /health mỗi phút -> web tự xin link / bật lại tunnel (kể cả chưa ai mở trang quản trị) ───
(
    # Chờ PHP sẵn sàng (tối đa ~10 s) rồi gõ ngay: chạy lại sau sự cố thì tunnel bật lại sớm nhất có thể (R3-07, R5-04).
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        sleep 0.5
        curl -s -o /dev/null --max-time 2 "http://localhost:$PORT/health" && break
    done
    LAST=""
    while true; do
        curl -s -o /dev/null --max-time 60 "http://localhost:$PORT/health?beat=1"
        H="$("$PHP_EXE" -r '$p=json_decode((string)@file_get_contents($argv[1]),true); echo is_array($p)&&($p["mode"]??"")==="token"?(string)($p["hostname"]??""):"";' "$TUN_FILE" 2>/dev/null)"
        [ -z "$H" ] && H="$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$CF_CONF_DIR/tunnel.log" 2>/dev/null | grep -v '//api\.' | tail -1 | sed 's#https://##')"
        if [ -n "$H" ] && [ "$H" != "$LAST" ]; then
            LAST="$H"
            echo ""
            echo "  >>> Link cho khách mời: https://$H   (mã QR: Quản trị → Tổng quan)"
        fi
        sleep 60
    done
) &
BEAT_PID=$!
disown "$BEAT_PID" 2>/dev/null   # không in "Terminated … ( sleep …" khi tắt (vẫn tự tắt trong cleanup)

# ─── Tự mở trình duyệt khi PHP đã sẵn sàng (ANHCUOI_NO_BROWSER=1 để tắt; lỗi thì bỏ qua) ───
if [ -z "$ANHCUOI_NO_BROWSER" ]; then
    (
        for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
            sleep 0.5
            curl -s -o /dev/null --max-time 2 "http://localhost:$PORT/health" && break
        done
        if [ "$(uname -s)" = "Darwin" ]; then
            open "http://localhost:$PORT/" >/dev/null 2>&1
        elif command -v xdg-open >/dev/null 2>&1; then
            xdg-open "http://localhost:$PORT/" >/dev/null 2>&1
        fi
    ) &
    OPEN_PID=$!
    disown "$OPEN_PID" 2>/dev/null
fi

# ─── PHP ─────────────────────────────────────────────────────────────────────
# Ảnh điện thoại 5–20 MB, ảnh máy ảnh RAW→JPEG có thể 30–60 MB; GD cần RAM cỡ 4 byte/điểm ảnh.
# Số tiến trình PHP (R5-05, số đo ở Docs/logs/r5-05-php-workers.md): PHP 8.1 trên Linux với 4 worker treo ~0,5% yêu cầu
# song song tới 10 s; PHP ≥ 8.2 (macOS, Docker 8.3, gói NAS 8.3) không treo -> PHP < 8.2 chỉ chạy 1 tiến trình.
if [ -z "$PHP_CLI_SERVER_WORKERS" ] && "$PHP_EXE" -r 'exit(PHP_VERSION_ID >= 80200 ? 0 : 1);' 2>/dev/null; then
    PHP_CLI_SERVER_WORKERS=4
fi
# 1 tiến trình = không đặt biến (PHP báo "number of workers must be larger than 1" nếu đặt 1).
if [ "${PHP_CLI_SERVER_WORKERS:-0}" -gt 1 ] 2>/dev/null; then
    export PHP_CLI_SERVER_WORKERS
else
    unset PHP_CLI_SERVER_WORKERS
fi
cd "$WEB_ROOT" || exit 1

# ─── Nhật ký php -S (S1-FREE-04): mỗi kết nối 2 dòng "Accepted/Closing" + 1 dòng "[200]: GET …" làm trôi dòng link cho
# khách. Đầy đủ ghi vào database/server.log (cắt khi > 5 MB; router chặn database/ nên không lộ ra web); ra màn hình
# chỉ dòng có ích: lỗi PHP, yêu cầu 4xx/5xx, "started"… Qua FIFO ở thư mục tạm (USB exFAT không tạo được FIFO ->
# in thẳng như cũ). PHP vẫn là con trực tiếp của script (R5-04 cần PID).
PHP_LOG="$DB_DIR/server.log"
php_log_filter() {
    local line n=0
    : > "$PHP_LOG" 2>/dev/null
    while IFS= read -r line; do
        printf '%s\n' "$line" >> "$PHP_LOG" 2>/dev/null
        case "$line" in
            *" Accepted"|*" Closing"|*" [2"[0-9][0-9]"]: "*|*" [3"[0-9][0-9]"]: "*) ;;
            *) printf '%s\n' "$line" ;;
        esac
        n=$((n + 1))
        if [ $((n % 2000)) -eq 0 ] && [ "$(wc -c < "$PHP_LOG" 2>/dev/null || echo 0)" -gt 5000000 ]; then
            : > "$PHP_LOG" 2>/dev/null
        fi
    done
}
FIFO_DIR="$(mktemp -d "${TMPDIR:-/tmp}/anhcuoi_log_XXXXXX" 2>/dev/null)"
if [ -n "$FIFO_DIR" ] && mkfifo "$FIFO_DIR/php.fifo" 2>/dev/null; then
    LOG_FIFO="$FIFO_DIR/php.fifo"
    php_log_filter < "$LOG_FIFO" &
    FILTER_PID=$!
    disown "$FILTER_PID" 2>/dev/null
    PHP_ERR="$LOG_FIFO"
else
    [ -n "$FIFO_DIR" ] && rmdir "$FIFO_DIR" 2>/dev/null
    PHP_ERR="/dev/stderr"
fi
# Chạy NỀN rồi chờ (không exec): script biết PID để khi PHP chết hay Ctrl+C thì tắt cả worker (R5-04).
# display_errors=0: php.ini Homebrew mặc định display_errors=STDOUT -> cảnh báo "POST Content-Length exceeds…" in vào
# thân phản hồi TRƯỚC khi index.php kịp tắt (S1-SEC-01); lỗi vẫn ghi log (stderr -> server.log).
"$PHP_EXE" \
    -d upload_max_filesize=64M \
    -d post_max_size=70M \
    -d memory_limit=768M \
    -d max_file_uploads=50 \
    -d max_execution_time=300 \
    -d max_input_vars=5000 \
    -d date.timezone=Asia/Ho_Chi_Minh \
    -d expose_php=Off \
    -d display_errors=0 \
    -d log_errors=1 \
    -S "$BIND:$PORT" router.php 2>"$PHP_ERR" &
PHP_PID=$!
wait "$PHP_PID" 2>/dev/null
RC=$?
[ "$RC" -gt 128 ] && echo "[!] PHP dừng bất thường (mã $RC)."
exit "$RC"
