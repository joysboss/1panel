#1panel
基于okxlin/docker-1panel和bilibili-koryking/1panel-docker的项目修改而来

#使用apline为基础镜像重新构建！



#
docker run -d \
    --name 1panel \
    --restart always \
    -p 10086:10086 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /var/lib/docker/volumes:/var/lib/docker/volumes \
    -v /home/1panel/opt/:/opt \
    -v /root:/root \
    -e TZ=Asia/Shanghai \
	-e PANEL_ENTRANCE=sunnas \
	-e PANEL_USERNAME=admin  \
	-e PANEL_PASSWORD=sun@891026 \
    sunnas/1panel:latest
