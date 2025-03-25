# 构建阶段
FROM alpine:3.19 AS builder

# 设置环境变量
ENV TZ=Asia/Shanghai \
    PANEL_BASE_DIR=/opt \
    PANEL_PORT=10086 \
    PANEL_USERNAME=1panel \
    PANEL_PASSWORD=1panel_password \
    PANEL_ENTRANCE=entrance \
    INSTALL_MODE=stable \
    FORCE_INSTALL=true \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN \
    LC_ALL=zh_CN.UTF-8

# 安装必要的依赖并下载1Panel
RUN apk add --no-cache \
    curl \
    wget \
    git \
    sqlite \
    tzdata \
    bash \
    shadow \
    musl-locales \
    musl-locales-lang \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && echo "export LANG=zh_CN.UTF-8" >> /etc/profile.d/locale.sh \
    && echo "export LANGUAGE=zh_CN" >> /etc/profile.d/locale.sh \
    && echo "export LC_ALL=zh_CN.UTF-8" >> /etc/profile.d/locale.sh \
    && chmod +x /etc/profile.d/locale.sh \
    && mkdir -p /app \
    && cd /app \
    && ARCH=$(uname -m) \
    && if [ "$ARCH" = "armv7l" ]; then ARCH="armv7"; fi \
    && if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi \
    && if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi \
    && VERSION=$(curl -s https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/latest) \
    && package_file_name="1panel-${VERSION}-linux-${ARCH}.tar.gz" \
    && package_download_url="https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/${VERSION}/release/${package_file_name}" \
    && HASH_FILE_URL="https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/${VERSION}/release/checksums.txt" \
    && echo "Downloading ${package_download_url}" \
    && wget -q --show-progress -O ${package_file_name} "$package_download_url" \
    && if [ ! -f ${package_file_name} ]; then echo "Failed to download ${package_file_name}" && exit 1; fi \
    && if [ ! -s ${package_file_name} ]; then echo "Downloaded file is empty" && exit 1; fi \
    && expected_hash=$(curl -s "$HASH_FILE_URL" | grep "$package_file_name" | awk '{print $1}') \
    && actual_hash=$(sha256sum "$package_file_name" | awk '{print $1}') \
    && if [ "$expected_hash" != "$actual_hash" ]; then echo "Hash verification failed" && exit 1; fi \
    && tar -tzf ${package_file_name} >/dev/null 2>&1 || { echo "Invalid tar file" && exit 1; } \
    && tar zxvf ${package_file_name} --strip-components 1 \
    && rm -f ${package_file_name} \
    && chmod +x /app/1panel /app/1pctl

# 最终阶段
FROM alpine:3.19

# 添加元数据标签
LABEL maintainer="1Panel Team <support@1panel.cn>" \
      description="1Panel - Linux Server Management Panel" \
      version="latest"

# 设置环境变量
ENV TZ=Asia/Shanghai \
    PANEL_BASE_DIR=/opt \
    PANEL_PORT=10086 \
    PANEL_USERNAME=1panel \
    PANEL_PASSWORD=1panel_password \
    PANEL_ENTRANCE=entrance \
    INSTALL_MODE=stable \
    FORCE_INSTALL=true \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN \
    LC_ALL=zh_CN.UTF-8

# 安装必要的依赖并设置环境
RUN apk add --no-cache \
    curl \
    wget \
    git \
    sqlite \
    tzdata \
    bash \
    shadow \
    musl-locales \
    musl-locales-lang \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && echo "export LANG=zh_CN.UTF-8" >> /etc/profile.d/locale.sh \
    && echo "export LANGUAGE=zh_CN" >> /etc/profile.d/locale.sh \
    && echo "export LC_ALL=zh_CN.UTF-8" >> /etc/profile.d/locale.sh \
    && chmod +x /etc/profile.d/locale.sh \
    && mkdir -p /opt/1panel/{data,logs,db} \
    && chmod -R 755 /opt/1panel \
    && touch /opt/1panel/db/1Panel.db \
    && sqlite3 /opt/1panel/db/1Panel.db "CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT);" \
    && sqlite3 /opt/1panel/db/1Panel.db "INSERT OR REPLACE INTO settings (key, value) VALUES ('SystemVersion', '$(curl -s https://resource.fit2cloud.com/1panel/package/stable/latest)');" \
    && chown 1000:1000 /opt/1panel/db/1Panel.db \
    && chmod 600 /opt/1panel/db/1Panel.db

# 从构建阶段复制文件
COPY --from=builder /app/1panel /usr/local/bin/
COPY --from=builder /app/1pctl /usr/local/bin/
COPY install.override.sh /app/
COPY update_app_version.sh /app/

# 设置执行权限
RUN chmod +x /usr/local/bin/1panel /usr/local/bin/1pctl /app/install.override.sh /app/update_app_version.sh

# 创建Docker套接字的卷
VOLUME /var/run/docker.sock

# 暴露端口
EXPOSE 10086

# 添加健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PANEL_PORT}/${PANEL_ENTRANCE}/api/v1/health || exit 1

# 设置启动命令
CMD ["/bin/sh", "-c", "source /etc/profile.d/locale.sh && cd /app && ./install.override.sh"]
