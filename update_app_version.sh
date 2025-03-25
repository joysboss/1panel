#!/bin/bash

set -euo pipefail

function validate_version() {
    local version=$(curl -s https://resource.fit2cloud.com/1panel/package/stable/latest)
    if [[ -z "$version" ]]; then
        echo "无法获取最新版本号"
        exit 1
    fi
    echo "$version"
}

function backup_database() {
    local db_file="${PANEL_BASE_DIR}/1panel/db/1Panel.db"
    if [[ -f "$db_file" ]]; then
        local timestamp=$(date +"%Y%m%d%H%M%S")
        cp "$db_file" "${db_file}.bak.${timestamp}"
    fi
}

function update_database() {
    local version=$(validate_version)
    local db_file="${PANEL_BASE_DIR}/1panel/db/1Panel.db"
    
    if [[ -f "$db_file" ]]; then
        backup_database
        sqlite3 "$db_file" <<EOF
UPDATE settings
SET value = '$version'
WHERE key = 'SystemVersion';
EOF
        echo "数据库版本已更新为 $version"
    else
        echo "数据库文件不存在: $db_file"
        exit 1
    fi
}

update_database
