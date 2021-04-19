#!/bin/bash

# 安装 harbor 私有仓库
# 官网地址： https://github.com/goharbor/harbor/releases
# docker-compose github地址 https://github.com/docker/compose/releases

set +e
set -o noglob

#
# Set Colors
#

bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)

red=$(tput setaf 1)
green=$(tput setaf 76)
white=$(tput setaf 7)
tan=$(tput setaf 202)
blue=$(tput setaf 25)

#
# Headers and Logging
#

underline() { printf "${underline}${bold}%s${reset}\n" "$@" }
bold() { printf "${bold}%s${reset}\n" "$@"}
h1() { printf "\n${underline}${bold}${blue}%s${reset}\n" "$@" }
h2() { printf "\n${underline}${bold}${white}%s${reset}\n" "$@" }
debug() { printf "${white}%s${reset}\n" "$@"}
info() { printf "${white}➜ %s${reset}\n" "$@"}
success() { printf "${green}✔ %s${reset}\n" "$@"}
error() { printf "${red}✖ %s${reset}\n" "$@"}
warn() { printf "${tan}➜ %s${reset}\n" "$@"}
note() { printf "\n${underline}${bold}${blue}Note:${reset} ${blue}%s${reset}\n" "$@"}

set -e

if [ $(whoami) != 'root' ]; then
     error "必须以root用户执行"
     exit 1
fi

CLOUMNS=$(stty size | awk '{print $NF}')

info "Step 1. 安装基础包"
printf "%-${CLOUMNS}s" "=" | sed 's/ /=/g'
for i in yum-utils device-mapper-persistent-data lvm2; do
    if [[ $(rpm -qa | grep $i | wc -l) -ge 1 ]]; then
        echo "Already installed --> $(rpm -qa | grep $i)"
    else
        echo "Installing --> $i"
        yum -y install ${i}
    fi
done

echo -e "2. 安装 docker-ce"
printf "%-${CLOUMNS}s" "=" | sed 's/ /=/g'
for i in docker-ce docker-ce-cli containerd.io;do
    if [[ $(rpm -qa | grep $i | wc -l) -ge 1 ]];then
        echo "Already installed --> $(rpm -qa | grep $i)"
    else
        if [ -f "/etc/yum.repos.d/docker-ce.repo" ]; then
            echo "File \"/etc/yum.repos.d/docker-ce.repo\" exists"
        else
            echo "add-repo https://download.docker.com/linux/centos/docker-ce.repo"
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        fi
        echo "Installing --> ${i}"
        yum -y install ${i}
    fi
done

echo -e "3. 配置 /etc/docker/daemon.json"
printf "%-${CLOUMNS}s" "=" | sed 's/ /=/g'
if [ ! -f "/etc/docker/daemon.json" ]; then
    read -p "请输入保存 docker镜像 的路径：" DATAROOT
    if [ ! -d "${DATAROOT}" ]; then
        mkdir -p ${DATAROOT}
        [ $? -ne 0 ] && { echo -e "${DATAROOT} 路径创建失败 请核查";exit 1; }
    fi
    mkdir -p /etc/docker
tee /etc/docker/daemon.json <<-EOF
{
	"data-root": "${DATAROOT}",
	"registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn/",
        "https://hub-mirror.c.163.com/",
        "https://reg-mirror.qiniu.com"
	]
}
EOF
else
    echo -e "FILE /etc/docker/daemon.json 已存在"
    cat /etc/docker/daemon.json
fi

echo -e "4. 安装 docker-compose"
printf "%-${CLOUMNS}s" "=" | sed 's/ /=/g'
if [ -f "/usr/local/bin/docker-compose" ]; then
    echo "File \"/usr/local/bin/docker-compose\" exists"
else
    echo -e "下载 https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)"
    curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    if [ $? -eq 0 ];then
        chmod +x /usr/local/bin/docker-compose
        echo "docker-compose 版本:"
        docker-compose --version
    fi
fi

echo -e "5. 安装 harbor"
printf "%-${CLOUMNS}s" "=" | sed 's/ /=/g'
read -p "请输入保存 harbor-offline.tgz 的文件路径: " SAVEPATH
[ -d ${SAVEPATH} ] || mkdir -p ${SAVEPATH} && cd ${SAVEPATH}
if [ ! -f harbor-offline-installer-v2.2.1.tgz ];then
    echo -e "正在下载 harbor-offline-installer-v2.2.1.tgz 请耐心等待..."
    wget https://github.com/goharbor/harbor/releases/download/v2.2.1/harbor-offline-installer-v2.2.1.tgz
    if [ $? -ne 0 ];then
        echo -e "下载失败 harbor-offline-installer-v2.2.1.tgz 请核查"
        exit 1
    fi
fi

echo -e "解压 harbor-offline-installer-v2.2.1.tgz "
tar -zxf harbor-offline-installer-v2.2.1.tgz

read -p "请输入 harbor 域名，此域名用于docker images tag；输入的域名会写入到/etc/hosts文件中(ex: xxx.com): " DOMAINNAME
read -p "请输入当前服务器IP(ex: 192.168.x.x): " CURIP
echo -e "把 域名与IP 写入系统hosts"
echo "${CURIP} ${DOMAINNAME}" | tee -a /etc/hosts

CERTSPATH="/etc/harbor/certs"
echo -e "创建目录 并 添加 HTTPS 密钥 ${CERTSPATH}"
mkdir -p "${CERTSPATH}" && cd ${CERTSPATH}
/bin/openssl genrsa -out ${CERTSPATH}/ca.key 2048
/bin/openssl req -x509 -new -nodes -key ${CERTSPATH}/ca.key -subj "/CN=${DOMAINNAME}" -days 5000 -out ${CERTSPATH}/ca.crt

echo -e "修改 harbor.yml 配置"
cd ${SAVEPATH}/harbor
cp harbor.yml.tmpl harbor.yml
sed -i "/^hostname/c\hostname: ${DOMAINNAME}" harbor.yml
read -p "请输入 harbor 使用的 http port: " HTTPPORT
sed -i "s/port: 80/port: ${HTTPPORT}/g" harbor.yml
read -p "请输入 harbor 使用的 https port: " HTTPSPORT
sed -i "s/port: 443/port: ${HTTPSPORT}/g" harbor.yml
sed -i "/certificate:/c\  certificate: ${CERTSPATH}/ca.crt" harbor.yml
sed -i "/private_key:/c\  private_key: ${CERTSPATH}/ca.key" harbor.yml
read -p "请输入 harbor 使用的 harbor_admin_password: " HARBORADMINPW
sed -i "/harbor_admin_password:/c\harbor_admin_password: ${HARBORADMINPW}" harbor.yml
read -p "请输入 harbor 使用的 database password: " DATABASEPW
sed -i "/^  password:/c\  password: ${DATABASEPW}" harbor.yml
read -p "请输入 harbor 使用的存储目录 data_volume: " DATAVOLUME
sed -i "/data_volume:/c\data_volume: ${DATAVOLUME}" harbor.yml
mkdir -p ${DATAVOLUME}

echo -e "执行 harbor 安装脚本"
./install.sh
if [ $? -eq 0 ]; then

    echo -e "harbor 安装完成 "
elif [ condition ]; then
     # else if body
else
     # else body
fi
