#!/bin/bash

######################
# 作者: 三叶草
# 最后修改时间: 2021-04-16 11:16:45
######################

#
# 添加用户
#

LOCALDIR=$(cd `dirname $0`;pwd)
CONFIGPATH="${LOCALDIR}/config.ini"

if [ -f ${CONFIGPATH} ];then
    source ${CONFIGPATH}
else
    echo "${CONFIGPATH} 配置文件找不到，请核查"
    exit 1
fi

[ -d ${OVPN_EASYRSA_PATH} ] || {
    echo "${OVPN_EASYRSA_PATH} 路径找不到，请核查"
    exit 1
}
[ -f /bin/expect ] || {
    echo "/bin/expect 路径找不到，请先安装 yum -y install expect"
    exit 1
}

function check_exist() {
    local username="$1"
    checkPathArr=(
        ${OVPN_EASYRSA_PATH}/pki/reqs/${username}.req
        ${OVPN_EASYRSA_PATH}/pki/private/${username}.key
        ${OVPN_EASYRSA_PATH}/pki/issued/${username}.crt
    )
    for path in ${checkPathArr[@]}; do
        [ -f ${path} ] && {
            echo "用户 ${username} 已存在，不能重复添加"
            exit 1
        }
    done
}

function add_user() {
    local username="$1"
    [ -z ${OVPN_CA_PASSWD} ] && {
        echo "CA 密码为空，请核查"
        exit 1
    }
    cd ${OVPN_EASYRSA_PATH}
    # ./easyrsa build-client-full ${username} nopass
    /bin/expect <<-EOF
spawn ./easyrsa build-client-full ${username} nopass
expect {
"Enter pass phrase for *" {send "${OVPN_CA_PASSWD}\\r"}
}
expect eof
EOF
    echo "=========================================="
    echo "用户 ${username} 添加完成"
    echo "=========================================="
}

function get_client_config() {
    [ -d ${OVPN_CLIENT_PATH} ] || mkdir -p ${OVPN_CLIENT_PATH}
    local username=$1
    ovpnFile="${OVPN_CLIENT_PATH}/${username}.ovpn"
    echo "
client
nobind
dev tun
proto ${OVPN_PROTO}
remote-cert-tls server
remote ${OVPN_SERVER_IP} ${OVPN_SERVER_PORT}
resolv-retry infinite
persist-key
persist-tun
comp-lzo
verb 3
auth-nocache
key-direction 1

<key>
$(cat $OVPN_EASYRSA_PATH/pki/private/${username}.key)
</key>
<cert>
$(/bin/openssl x509 -in $OVPN_EASYRSA_PATH/pki/issued/${username}.crt)
</cert>
<ca>
$(cat $OVPN_EASYRSA_PATH/pki/ca.crt)
</ca>
<tls-auth>
$(cat $OVPN_EASYRSA_PATH/pki/ta.key)
</tls-auth>
" > ${ovpnFile}
    echo "OVPN文件创建完成 ${ovpnFile}"
    echo "=========================================="
}

[ $# -ne 2 ] && {
    echo "Usage: $0 -n username"
    exit 1
}

while getopts "n:h" opt; do
    case "$opt" in
    n)
        username=${OPTARG}
        check_exist ${username}
        add_user ${username}
        get_client_config ${username}
        ;;
    h | ?)
        echo "Usage: $0 -n username"
        exit 1
        ;;
    esac
done