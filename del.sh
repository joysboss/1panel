#!/bin/bash
#运行日志输出到当前目录
docker logs 1panel > ./error.log

# 列出所有包含 sunnas/1panel 的容器，并提取容器 ID
container_ids=$(docker ps -a | grep sunnas/1panel | awk '{print $1}')

# 停止容器
if [ -n "$container_ids" ]; then
    echo "Stopping containers: $container_ids"
    docker stop $container_ids
else
    echo "No containers found with image sunnas/1panel."
fi

# 删除容器
if [ -n "$container_ids" ]; then
    echo "Removing containers: $container_ids"
    docker rm $container_ids
fi    


#删除镜像
#docker rmi sunnas/1panel:latest
