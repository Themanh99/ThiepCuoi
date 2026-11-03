#!/bin/sh
# Nạp lại nginx khi certbot thay chứng chỉ. Chạy nền từ /docker-entrypoint.d lúc container khởi động.

CERT=/etc/nginx/certs/fullchain.pem

(
    last=$(cksum "$CERT" 2>/dev/null)
    while sleep 60; do
        current=$(cksum "$CERT" 2>/dev/null)
        [ "$current" = "$last" ] && continue
        nginx -t -q && nginx -s reload && last=$current
    done
) </dev/null &
