#!/bin/sh
# Xin và gia hạn chứng chỉ Let's Encrypt qua webroot, rồi chép sang thư mục nginx đọc.
# Lần đầu chưa có chứng chỉ thì tạo tạm một cái tự ký, nếu không nginx không khởi động được
# và Let's Encrypt cũng không xác thực được domain.

CERT_NAME=anhcuoi
LIVE=/etc/letsencrypt/live/$CERT_NAME
CERTS=/certs
WEBROOT=/var/www/acme
NGINX_UID=101
RENEW_INTERVAL=43200
# Let's Encrypt khóa 1 giờ nếu xác thực sai 5 lần, nên không thử lại dày hơn mức này
RETRY_INTERVAL=1800

FIRST_DOMAIN=${SERVER_NAME%% *}
DOMAIN_ARGS=
for domain in $SERVER_NAME; do
    DOMAIN_ARGS="$DOMAIN_ARGS -d $domain"
done

EMAIL_ARGS=--register-unsafely-without-email
if [ -n "$LE_EMAIL" ]; then
    EMAIL_ARGS="--email $LE_EMAIL"
fi

trap 'exit 0' TERM INT

pause() {
    sleep "$1" &
    wait $!
}

# Đổi key trước, fullchain sau cùng: nginx chỉ reload khi fullchain đổi
publish() {
    src=$1
    (
        umask 077
        cp "$src/privkey.pem" "$CERTS/.privkey.pem.new"
        cp "$src/fullchain.pem" "$CERTS/.fullchain.pem.new"
    ) || return 1
    chown "$NGINX_UID:$NGINX_UID" "$CERTS/.privkey.pem.new" "$CERTS/.fullchain.pem.new" || return 1
    mv -f "$CERTS/.privkey.pem.new" "$CERTS/privkey.pem" &&
        mv -f "$CERTS/.fullchain.pem.new" "$CERTS/fullchain.pem"
}

create_placeholder() {
    tmp=$(mktemp -d)
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 30 \
        -subj "/CN=$FIRST_DOMAIN" -keyout "$tmp/privkey.pem" -out "$tmp/fullchain.pem" 2>/dev/null
    publish "$tmp"
    rm -rf "$tmp"
    echo "Da tao chung chi tam tu ky cho $FIRST_DOMAIN"
}

# Tránh tốn lượt xác thực khi nginx chưa lên
wait_for_nginx() {
    probe=$WEBROOT/.well-known/acme-challenge/probe
    mkdir -p "$(dirname "$probe")"
    chmod 755 "$WEBROOT/.well-known" "$(dirname "$probe")"
    echo ok > "$probe"
    chmod 644 "$probe"
    until wget -q -T 5 -O /dev/null --header "Host: $FIRST_DOMAIN" \
        "http://nginx:8080/.well-known/acme-challenge/probe"; do
        pause 5
    done
    rm -f "$probe"
}

if [ -s "$CERTS/fullchain.pem" ] && [ -s "$CERTS/privkey.pem" ]; then
    :
else
    create_placeholder || exit 1
fi

while :; do
    wait_for_nginx

    # --keep-until-expiring: chưa tới hạn thì không xin lại, nên dùng chung cho cấp mới và gia hạn
    # shellcheck disable=SC2086
    certbot certonly --webroot -w "$WEBROOT" --cert-name "$CERT_NAME" $DOMAIN_ARGS \
        --non-interactive --agree-tos --keep-until-expiring $EMAIL_ARGS

    if [ $? -ne 0 ]; then
        echo "Khong xin duoc chung chi cho: $SERVER_NAME. Kiem tra DNS tro ve server va cong 80 mo. Thu lai sau $RETRY_INTERVAL giay."
        pause "$RETRY_INTERVAL"
        continue
    fi

    if ! cmp -s "$LIVE/fullchain.pem" "$CERTS/fullchain.pem"; then
        publish "$LIVE" && echo "Da cap nhat chung chi cho: $SERVER_NAME"
    fi
    pause "$RENEW_INTERVAL"
done
