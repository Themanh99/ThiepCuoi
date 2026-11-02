# ─── Ảnh Cưới – Docker image (tự chủ, không gọi ra ngoài) ──────────────────────
# PHP 8.3 built-in server, chạy sau reverse proxy. KHÔNG có cloudflared.
# Build :  docker compose build
# Run   :  docker compose up -d
# ───────────────────────────────────────────────────────────────────────────────
FROM php:8.3-cli-alpine@sha256:86a7a8f46bbf73120a19cf72246f606b6de9aaa84a00971c25d187fbae44c211

LABEL description="Thiệp Cưới Online – PHP built-in server, không kết nối ra ngoài"

# ─── Cài extension PHP cần thiết ──────────────────────────────────────────────
# Thư viện -dev chỉ dùng lúc biên dịch, gỡ ngay sau đó; giữ lại thư viện chạy.
RUN apk add --no-cache \
        bash \
        curl \
        freetype \
        libjpeg-turbo \
        libpng \
        libwebp \
        libzip \
        sqlite-libs \
    && apk add --no-cache --virtual .build-deps \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libzip-dev \
        sqlite-dev \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo_sqlite \
        gd \
        zip \
        exif \
    && apk del .build-deps

# ─── Cấu hình PHP ────────────────────────────────────────────────────────────
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY docker/php.ini "$PHP_INI_DIR/conf.d/anhcuoi.ini"

# ─── Copy mã nguồn ───────────────────────────────────────────────────────────
WORKDIR /var/www/anhcuoi

# Copy toàn bộ mã nguồn (trừ những thứ trong .dockerignore)
COPY . .

# ─── Tài khoản không đặc quyền + khóa tunnel ─────────────────────────────────
# Mã nguồn thuộc root; ứng dụng chỉ ghi được database, uploads, application/logs.
# tunnel.json thuộc root nên không bật lại tunnel được từ giao diện quản trị.
RUN addgroup -S -g 10001 anhcuoi \
    && adduser -S -D -H -u 10001 -G anhcuoi anhcuoi \
    && mkdir -p database/sessions uploads/photos uploads/media application/logs cloudflared \
    && printf '{"mode":"off","token":"","hostname":"","auto":false}' > cloudflared/tunnel.json \
    && chown -R root:root . \
    && chmod -R a+rX,go-w . \
    && chmod 0555 cloudflared \
    && chmod 0444 cloudflared/tunnel.json \
    && chown -R anhcuoi:anhcuoi database uploads application/logs \
    && chmod 0700 database application/logs \
    && chmod 0755 uploads uploads/photos uploads/media

# ─── Script khởi chạy ────────────────────────────────────────────────────────
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

# ─── Cổng mặc định ───────────────────────────────────────────────────────────
ENV ANHCUOI_PORT=8686
ENV ANHCUOI_BIND=0.0.0.0
ENV PHP_CLI_SERVER_WORKERS=4

EXPOSE 8686

USER anhcuoi

ENTRYPOINT ["entrypoint.sh"]
