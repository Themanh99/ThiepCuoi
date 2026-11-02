<?php
// Chạy trước router.php cho mọi request (docker/router.php; built-in server bỏ qua auto_prepend_file với router). Ứng dụng chỉ biết hai kiểu truy cập: trực tiếp và qua Cloudflare Tunnel.
// Request qua reverse proxy (có X-Real-IP) được quy về kiểu tunnel để ứng dụng nhận đúng IP khách
// (client_ip) và chặn trang /setup trên domain công khai (via_tunnel). Cài đặt lần đầu làm qua SSH tunnel (cổng 8081 của nginx, không gửi X-Real-IP).
// Container không publish cổng nên X-Real-IP chỉ đến từ proxy; proxy phải luôn ghi đè header này.
unset($_SERVER['HTTP_CF_CONNECTING_IP'], $_SERVER['HTTP_CF_RAY']);
$ac_real_ip = isset($_SERVER['HTTP_X_REAL_IP']) ? trim((string) $_SERVER['HTTP_X_REAL_IP']) : '';
if ($ac_real_ip !== '') {
    $_SERVER['REMOTE_ADDR'] = '127.0.0.1';
    $_SERVER['HTTP_CF_CONNECTING_IP'] = filter_var($ac_real_ip, FILTER_VALIDATE_IP) ? $ac_real_ip : '0.0.0.0';
}
unset($ac_real_ip);

// Trình duyệt chỉ được tải tài nguyên từ chính domain này (chặn cả iframe Google Maps).
// JS của ứng dụng tự giải mã bằng eval nên phải giữ unsafe-eval.
if (PHP_SAPI === 'cli-server') {
    header("Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
        . "style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; media-src 'self' blob:; "
        . "connect-src 'self'; frame-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'self'");
}
