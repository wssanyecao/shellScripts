#!/bin/bash

# 安装docker

read -p "please input docker data-root path: " dataroot
if [ ! -d ${dataroot} ]; then
     mkdir -p ${dataroot}
else
     echo "docker data-root is : ${dataroot}"
fi


echo -e "======= Uninstall installed docker =========="
sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine

echo -e "======= Set up repository =========="
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

echo -e "======= Use Aliyun Docker =========="
sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# check version
#sudo yum list docker-ce --showduplicates | sort -r

# install Specified version
# sudo yum -y install docker-ce-<VERSION_STRING> docker-ce-cli-<VERSION_STRING> containerd.io

# install new
sudo yum -y install docker-ce docker-ce-cli containerd.io

sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-EOF
{

	"data-root": "${dataroot}",
	"registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn/",
        "https://hub-mirror.c.163.com/",
        "https://reg-mirror.qiniu.com"
	]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker

# install docker-compose
wget https://bootstrap.pypa.io/pip/2.7/get-pip.py
if [ -f get-pip.py ]; then
     python get-pip.py
     pip install docker-compose
fi
