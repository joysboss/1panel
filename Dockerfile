# 构建阶段
FROM alpine:3.19 

# 设置环境变量，避免交互式配置
ARG DEBIAN_FRONTEND=noninteractive

# 设置时区为亚洲/上海
ENV TZ=Asia/Shanghai

# 安装所需的软件包并清理APK缓存
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
    && apk update && apk add --no-cache \
    wget \
    tar \
    unzip \
    gzip  \
    zip \
    curl \
    git \
    sudo \
    gnupg \
    sqlite \
    tzdata \
    bash   \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    rm -rf /var/cache/apk/*

   # 设置工作目录为/app
WORKDIR /app

# 复制必要的文件
COPY ./install.override.sh .
COPY ./update_app_version.sh .
 

# 下载并安装 1Panel
RUN apk add --no-cache curl tar && \
    INSTALL_MODE="stable" && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "armv7l" ]; then ARCH="armv7"; fi && \
    if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi && \
    if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi && \
    package_file_name="1panel-$(curl -s https://resource.fit2cloud.com/1panel/package/stable/latest)-linux-${ARCH}.tar.gz" && \
    package_download_url="https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/$(curl -s https://resource.fit2cloud.com/1panel/package/stable/latest)/release/${package_file_name}" && \
    echo "Downloading ${package_download_url}" && \
    curl -sSL -o ${package_file_name} "$package_download_url" && \
    tar zxvf ${package_file_name} --strip-components 1 && \
    rm /app/install.sh && \
    mv -f /app/install.override.sh /app/install.sh && \
    mkdir -p /etc/systemd/system/ && \
    cp /app/1panel.service /etc/systemd/system/1panel.service && \
    chmod +x /app/install.sh && \
    chmod +x /app/update_app_version.sh

 # 设置工作目录为根目录
WORKDIR /


# 创建 Docker 套接字的卷
VOLUME /var/run/docker.sock

# 启动
CMD ["/bin/bash", "-c", "/app/install.sh && /app/update_app_version.sh && /usr/local/bin/1panel"]