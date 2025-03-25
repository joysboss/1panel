#!/bin/bash

DEFAULT_BASE_DIR=/opt
DEFAULT_ENTRANCE="entrance"
DEFAULT_USERNAME="1panel"
DEFAULT_PASSWORD="1panel_password"

CURRENT_DIR=$(
    cd "$(dirname "$0")"
    pwd
)

# 设置错误处理
set -e
trap 'handle_error $? $LINENO' ERR

function handle_error() {
    local exit_code=$1
    local line_no=$2
    log "错误发生在第 $line_no 行，退出码: $exit_code"
    log "错误详情: $(caller)"
    exit $exit_code
}

function log() {
    local level="INFO"
    if [[ $1 == "ERROR" ]]; then
        level="ERROR"
        shift
    elif [[ $1 == "WARN" ]]; then
        level="WARN"
        shift
    fi
    message="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $1"
    echo -e "${message}" 2>&1 | tee -a ${CURRENT_DIR}/install.log
}

echo
cat << EOF
 ██╗    ██████╗  █████╗ ███╗   ██╗███████╗██╗     
███║    ██╔══██╗██╔══██╗████╗  ██║██╔════╝██║     
╚██║    ██████╔╝███████║██╔██╗ ██║█████╗  ██║     
 ██║    ██╔═══╝ ██╔══██║██║╚██╗██║██╔══╝  ██║     
 ██║    ██║     ██║  ██║██║ ╚████║███████╗███████╗
 ╚═╝    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝
EOF

log "======================= 开始安装 ======================="

function check_architecture() {
    osCheck=`uname -a`
    if [[ $osCheck =~ 'x86_64' ]];then
        architecture="amd64"
    elif [[ $osCheck =~ 'arm64' ]] || [[ $osCheck =~ 'aarch64' ]];then
        architecture="arm64"
    elif [[ $osCheck =~ 'armv7l' ]];then
        architecture="armv7"
    elif [[ $osCheck =~ 'ppc64le' ]];then
        architecture="ppc64le"
    elif [[ $osCheck =~ 's390x' ]];then
        architecture="s390x"
    else
        log "ERROR" "暂不支持的系统架构，请参阅官方文档，选择受支持的系统。"
        exit 1
    fi
    log "检测到系统架构: $architecture"
}

function check_install_mode() {
    if [[ ! ${INSTALL_MODE} ]];then
        INSTALL_MODE="stable"
    else
        if [[ ${INSTALL_MODE} != "dev" && ${INSTALL_MODE} != "stable" ]];then
            log "ERROR" "请输入正确的安装模式（dev or stable）"
            exit 1
        fi
    fi
    log "安装模式: $INSTALL_MODE"
}

function download_package() {
    VERSION=$(curl -s https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/latest)
    if [[ "x${VERSION}" == "x" ]];then
        log "ERROR" "获取最新版本失败，请稍候重试"
        exit 1
    fi

    package_file_name="1panel-${VERSION}-linux-${architecture}.tar.gz"
    package_download_url="https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/${VERSION}/release/${package_file_name}"
    HASH_FILE_URL="https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/${VERSION}/release/checksums.txt"
    expected_hash=$(curl -s "$HASH_FILE_URL" | grep "$package_file_name" | awk '{print $1}')

    if [ -f ${package_file_name} ];then
        actual_hash=$(sha256sum "$package_file_name" | awk '{print $1}')
        if [[ "$expected_hash" == "$actual_hash" ]];then
            log "安装包已存在且哈希值验证通过，跳过下载"
            return 0
        else
            log "WARN" "已存在安装包，但是哈希值不一致，开始重新下载"
            rm -f ${package_file_name}
        fi
    fi

    log "开始下载 1Panel ${VERSION} 版本在线安装包"
    log "安装包下载地址： ${package_download_url}"

    curl -LOk -o ${package_file_name} ${package_download_url}
    if [ ! -f ${package_file_name} ];then
        log "ERROR" "下载安装包失败，请稍候重试。"
        exit 1
    fi

    actual_hash=$(sha256sum "$package_file_name" | awk '{print $1}')
    if [[ "$expected_hash" != "$actual_hash" ]];then
        log "ERROR" "下载的安装包哈希值验证失败，请稍候重试。"
        rm -f ${package_file_name}
        exit 1
    fi

    log "安装包下载完成且哈希值验证通过"
    return 0
}

function Prepare_System(){
    # 检查是否真正安装（通过检查数据库文件）
    if [[ -f "${PANEL_BASE_DIR}/db/1Panel.db" ]] && [[ -s "${PANEL_BASE_DIR}/db/1Panel.db" ]]; then
        if [[ "${FORCE_INSTALL}" == "true" ]]; then
            log "检测到已安装的1Panel，将进行强制重新安装"
            rm -f /usr/local/bin/1panel /usr/bin/1panel
            rm -f /usr/local/bin/1pctl /usr/bin/1pctl
            rm -rf ${PANEL_BASE_DIR}/data/*
            rm -rf ${PANEL_BASE_DIR}/logs/*
            rm -rf ${PANEL_BASE_DIR}/db/*
        else
            log "1Panel Linux 服务器运维管理面板已安装，请勿重复安装"
            1panel
        fi
    else
        log "未检测到已安装的1Panel，开始安装"
    fi
}

function Set_Dir(){
    if [[ ! -d $PANEL_BASE_DIR ]]; then
        PANEL_BASE_DIR=${PANEL_BASE_DIR:-$DEFAULT_BASE_DIR}
        mkdir -p $PANEL_BASE_DIR
        log "安装路径已设置为 $PANEL_BASE_DIR"
    fi
}

function Set_Port(){
    PANEL_PORT=${PANEL_PORT:-10086}
    log "您设置的端口为：$PANEL_PORT"
}

function Set_Firewall(){
    if which firewall-cmd >/dev/null 2>&1; then
        if systemctl status firewalld | grep -q "Active: active" >/dev/null 2>&1;then
            log "防火墙开放 $PANEL_PORT 端口"
            firewall-cmd --zone=public --add-port=$PANEL_PORT/tcp --permanent
            firewall-cmd --reload
        else
            log "防火墙未开启，忽略端口开放"
        fi
    fi

    if which ufw >/dev/null 2>&1; then
        if systemctl status ufw | grep -q "Active: active" >/dev/null 2>&1;then
            log "防火墙开放 $PANEL_PORT 端口"
            ufw allow $PANEL_PORT/tcp
            ufw reload
        else
            log "防火墙未开启，忽略端口开放"
        fi
    fi
}

function Set_Username(){
    PANEL_USERNAME=${PANEL_USERNAME:-$DEFAULT_USERNAME}
    log "您设置的用户名称为：$PANEL_USERNAME"
}

function Set_Password(){
    PANEL_PASSWORD=${PANEL_PASSWORD:-$DEFAULT_PASSWORD}
}

function Init_Panel(){
    log "配置 1Panel Service"

    RUN_BASE_DIR=$PANEL_BASE_DIR/1panel
    mkdir -p $RUN_BASE_DIR

    cd ${CURRENT_DIR}

    cp ./1panel /usr/local/bin && chmod +x /usr/local/bin/1panel
    if [[ ! -f /usr/bin/1panel ]]; then
        ln -s /usr/local/bin/1panel /usr/bin/1panel >/dev/null 2>&1
    fi

    cp ./1pctl /usr/local/bin && chmod +x /usr/local/bin/1pctl
    sed -i -e "s#BASE_DIR=.*#BASE_DIR=${PANEL_BASE_DIR}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_PORT=.*#ORIGINAL_PORT=${PANEL_PORT}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_USERNAME=.*#ORIGINAL_USERNAME=${PANEL_USERNAME}#g" /usr/local/bin/1pctl
    ESCAPED_PANEL_PASSWORD=$(echo "$PANEL_PASSWORD" | sed 's/[!@#$%*_,.?]/\\&/g')
    sed -i -e "s#ORIGINAL_PASSWORD=.*#ORIGINAL_PASSWORD=${ESCAPED_PANEL_PASSWORD}#g" /usr/local/bin/1pctl
    PANEL_ENTRANCE=${PANEL_ENTRANCE:-$DEFAULT_ENTRANCE}
    sed -i -e "s#ORIGINAL_ENTRANCE=.*#ORIGINAL_ENTRANCE=${PANEL_ENTRANCE}#g" /usr/local/bin/1pctl
    if [[ ! -f /usr/bin/1pctl ]]; then
        ln -s /usr/local/bin/1pctl /usr/bin/1pctl >/dev/null 2>&1
    fi
}

function Show_Result(){
    log ""
    log "=================感谢您的耐心等待，安装已经完成=================="
    log ""
    log "请用浏览器访问面板:"
    log "面板地址: http://\$LOCAL_IP:$PANEL_PORT/$PANEL_ENTRANCE"
    log "用户名称: $PANEL_USERNAME"
    log "用户密码: $PANEL_PASSWORD"
    log ""
    log "项目官网: https://1panel.cn"
    log "项目文档: https://1panel.cn/docs"
    log "代码仓库: https://github.com/1Panel-dev/1Panel"
    log ""
    log "如果使用的是云服务器，请至安全组开放 $PANEL_PORT 端口"
    log ""
    log "================================================================"
}

function main(){
    check_architecture
    check_install_mode
    Prepare_System
    Set_Dir
    Set_Port
    Set_Firewall
    Set_Username
    Set_Password
    download_package
    Init_Panel
    Show_Result
}

main

